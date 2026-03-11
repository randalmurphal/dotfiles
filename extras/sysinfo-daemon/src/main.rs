use sysinfo::{Networks, System};
use std::{env, fs, path::PathBuf, process::Command, thread, time::Duration};

/// Detect if running in WSL and return the Windows user's home path if so.
/// Returns path like "/mnt/c/Users/Randy" if in WSL, None otherwise.
fn detect_wsl_windows_home() -> Option<PathBuf> {
    // Check if we're in WSL by looking for WSL-specific indicators
    let is_wsl = fs::read_to_string("/proc/version")
        .map(|v| v.to_lowercase().contains("microsoft") || v.to_lowercase().contains("wsl"))
        .unwrap_or(false);

    if !is_wsl {
        return None;
    }

    // First try: check for common Windows user directories directly
    // This is the most reliable method in systemd service context
    for username in &["Randy", "rmurphy"] {
        let path = PathBuf::from(format!("/mnt/c/Users/{}", username));
        if path.exists() && path.is_dir() {
            return Some(path);
        }
    }

    // Second try: use wslpath with USERPROFILE env var (works in interactive shells)
    if let Ok(userprofile) = env::var("USERPROFILE") {
        if !userprofile.is_empty() {
            if let Ok(output) = Command::new("wslpath").args(["-u", &userprofile]).output() {
                if output.status.success() {
                    let path = String::from_utf8_lossy(&output.stdout).trim().to_string();
                    // Validate it's actually a Windows user path
                    if path.starts_with("/mnt/") && PathBuf::from(&path).exists() {
                        return Some(PathBuf::from(path));
                    }
                }
            }
        }
    }

    None
}

fn format_throughput(bytes_per_sec: f64) -> String {
    if bytes_per_sec >= 1_000_000_000.0 {
        format!("{:.1} GB/s", bytes_per_sec / 1_000_000_000.0)
    } else if bytes_per_sec >= 1_000_000.0 {
        format!("{:.1} MB/s", bytes_per_sec / 1_000_000.0)
    } else if bytes_per_sec >= 1_000.0 {
        format!("{:.0} KB/s", bytes_per_sec / 1_000.0)
    } else {
        format!("{:.0} B/s", bytes_per_sec)
    }
}

/// Find the best network interface to monitor (cross-platform).
/// Priority: default route interface > first non-loopback from sysinfo
fn detect_network_interface(networks: &Networks) -> Option<String> {
    // Linux: try /proc/net/route for default route
    if let Ok(content) = fs::read_to_string("/proc/net/route") {
        for line in content.lines().skip(1) {
            let parts: Vec<&str> = line.split_whitespace().collect();
            // Default route has destination 00000000
            if parts.len() >= 2 && parts[1] == "00000000" {
                return Some(parts[0].to_string());
            }
        }
    }

    // macOS: use route command to find default interface
    // route lives in /sbin which may not be in PATH (e.g. launchd agents)
    if let Ok(output) = Command::new("/sbin/route").args(["-n", "get", "default"]).output() {
        if output.status.success() {
            let stdout = String::from_utf8_lossy(&output.stdout);
            for line in stdout.lines() {
                let trimmed = line.trim();
                if let Some(iface) = trimmed.strip_prefix("interface:") {
                    return Some(iface.trim().to_string());
                }
            }
        }
    }

    // Fallback: first non-loopback interface from sysinfo
    let mut candidates: Vec<&str> = networks
        .iter()
        .map(|(name, _)| name.as_str())
        .filter(|name| {
            *name != "lo"
                && !name.starts_with("docker")
                && !name.starts_with("br-")
                && !name.starts_with("veth")
        })
        .collect();
    candidates.sort();
    candidates.into_iter().next().map(|s| s.to_string())
}

/// Get cumulative rx/tx bytes for a network interface from sysinfo.
fn get_interface_bytes(networks: &Networks, interface: &str) -> Option<(u64, u64)> {
    networks
        .iter()
        .find(|(name, _)| name.as_str() == interface)
        .map(|(_, data)| (data.total_received(), data.total_transmitted()))
}

/// Find nvidia-smi binary path (WSL puts it in a non-standard location)
/// Checks file existence first to avoid failed process spawns on machines without a GPU.
fn find_nvidia_smi() -> Option<&'static str> {
    use std::path::Path;

    const PATHS: &[&str] = &[
        "/usr/lib/wsl/lib/nvidia-smi", // WSL2
        "/usr/bin/nvidia-smi",          // Standard Linux
    ];

    for path in PATHS {
        if !Path::new(path).is_file() {
            continue;
        }
        // Binary exists, verify it actually works
        let result = Command::new(path).arg("--version").output();
        if result.map(|o| o.status.success()).unwrap_or(false) {
            return Some(path);
        }
    }
    None
}

/// Query NVIDIA GPU stats via nvidia-smi.
/// Returns (gpu_util%, mem_used_mb, mem_total_mb) or None if unavailable.
fn query_nvidia_gpu(nvidia_smi_path: &str) -> Option<(u32, u32, u32)> {
    let output = Command::new(nvidia_smi_path)
        .args([
            "--query-gpu=utilization.gpu,memory.used,memory.total",
            "--format=csv,noheader,nounits",
        ])
        .output()
        .ok()?;

    if !output.status.success() {
        return None;
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    let parts: Vec<&str> = stdout.trim().split(',').map(|s| s.trim()).collect();

    if parts.len() >= 3 {
        let util = parts[0].parse().ok()?;
        let mem_used = parts[1].parse().ok()?;
        let mem_total = parts[2].parse().ok()?;
        Some((util, mem_used, mem_total))
    } else {
        None
    }
}

fn format_gpu_mem(mb: u32) -> String {
    if mb >= 1024 {
        format!("{:.1}G", mb as f64 / 1024.0)
    } else {
        format!("{}M", mb)
    }
}

fn main() {
    let mut sys = System::new();
    let mut networks = Networks::new_with_refreshed_list();

    let mut prev_rx: u64 = 0;
    let mut prev_tx: u64 = 0;
    let mut rx_ema: f64 = 0.0;
    let mut tx_ema: f64 = 0.0;
    let mut net_str = String::from("↓ 0 B/s ↑ 0 B/s");
    let mut gpu_str: Option<String> = None;
    let mut tick: u32 = 0;
    const EMA_ALPHA: f64 = 0.3; // 30% new, 70% history

    // Detect WSL and Windows home path for dual-write (no-op on macOS)
    let windows_sysinfo_path = detect_wsl_windows_home().map(|home| {
        let path = home.join(".wezterm-sysinfo");
        eprintln!("sysinfo-daemon: WSL detected, will also write to {:?}", path);
        path
    });

    // Detect network interface once at startup
    let net_interface = detect_network_interface(&networks);
    if let Some(ref iface) = net_interface {
        eprintln!("sysinfo-daemon: monitoring interface {}", iface);
        // Seed previous counters so first delta isn't "all bytes since boot"
        if let Some((rx, tx)) = get_interface_bytes(&networks, iface) {
            prev_rx = rx;
            prev_tx = tx;
        }
    } else {
        eprintln!("sysinfo-daemon: no network interface found, network stats disabled");
    }

    // Check if nvidia-smi is available once at startup (Linux/WSL only, no-op on macOS)
    let nvidia_smi_path = find_nvidia_smi();
    if let Some(path) = nvidia_smi_path {
        eprintln!(
            "sysinfo-daemon: NVIDIA GPU detected at {}, enabling GPU stats",
            path
        );
    }

    // Initial CPU refresh (first reading will be ~0%, same as original behavior)
    sys.refresh_cpu_usage();

    loop {
        // CPU (every tick at 2Hz base)
        sys.refresh_cpu_usage();
        let cpu_pct = sys.global_cpu_usage() as u64;

        // Network with EMA smoothing (every tick at 2Hz base = every 500ms)
        if let Some(ref iface) = net_interface {
            networks.refresh(true);
            let (rx, tx) = get_interface_bytes(&networks, iface).unwrap_or((0, 0));
            let rx_rate = (rx.saturating_sub(prev_rx)) as f64 * 2.0; // 500ms interval, *2 = per second
            let tx_rate = (tx.saturating_sub(prev_tx)) as f64 * 2.0;
            prev_rx = rx;
            prev_tx = tx;

            // Apply EMA: avg = avg * (1 - alpha) + new * alpha
            rx_ema = rx_ema * (1.0 - EMA_ALPHA) + rx_rate * EMA_ALPHA;
            tx_ema = tx_ema * (1.0 - EMA_ALPHA) + tx_rate * EMA_ALPHA;

            net_str = format!("↓ {} ↑ {}", format_throughput(rx_ema), format_throughput(tx_ema));
        }

        // GPU stats (every 2nd tick at 2Hz base = 1Hz, nvidia-smi is slow)
        if tick % 2 == 0 {
            if let Some(path) = nvidia_smi_path {
                gpu_str = query_nvidia_gpu(path).map(|(util, mem_used, mem_total)| {
                    format!(
                        "GPU: {}% {}/{}",
                        util,
                        format_gpu_mem(mem_used),
                        format_gpu_mem(mem_total)
                    )
                });
            }
        }

        // Memory (every tick)
        sys.refresh_memory();
        let used_gb = sys.used_memory() as f64 / (1024.0 * 1024.0 * 1024.0);
        let total_gb = sys.total_memory() as f64 / (1024.0 * 1024.0 * 1024.0);
        let mem_str = format!("RAM: {:.1}/{:.1}GB", used_gb, total_gb);

        // Build output: NET || CPU | RAM | GPU (if available)
        // The || separator lets WezTerm split network from the rest
        let output = match &gpu_str {
            Some(gpu) => format!(
                "{}||CPU: {:3}% | {} | {}",
                net_str, cpu_pct, mem_str, gpu
            ),
            None => format!("{}||CPU: {:3}% | {}", net_str, cpu_pct, mem_str),
        };

        // Always write to /tmp/sysinfo
        let _ = fs::write("/tmp/sysinfo", &output);

        // Write to Windows path less frequently (every 4th tick = 2s) since /mnt/c is slow (~12ms per write)
        if tick % 4 == 0 {
            if let Some(ref win_path) = windows_sysinfo_path {
                let _ = fs::write(win_path, &output);
            }
        }

        tick = tick.wrapping_add(1);
        thread::sleep(Duration::from_millis(500)); // 2Hz base tick
    }
}
