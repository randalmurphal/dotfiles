#!/usr/bin/env bash
set -euo pipefail

# Verify WSL
if ! grep -qi "microsoft\|wsl" /proc/version 2>/dev/null; then
    echo "Not running in WSL, skipping."
    exit 0
fi

echo "Configuring WSL environment..."

# /etc/wsl.conf
configure_wsl_conf() {
    local wsl_conf="/etc/wsl.conf"

    if [[ -f "$wsl_conf" ]] && grep -q "# Managed by dotfiles" "$wsl_conf"; then
        echo "wsl.conf already configured"
        return 0
    fi

    [[ -f "$wsl_conf" ]] && sudo cp "$wsl_conf" "${wsl_conf}.backup.$(date +%Y%m%d)"

    sudo tee "$wsl_conf" > /dev/null << EOF
# Managed by dotfiles

[boot]
systemd=true

[automount]
enabled = true
root = /mnt/
options = "metadata,umask=22,fmask=11"
mountFsTab = true

[interop]
enabled = true
appendWindowsPath = true

[network]
generateHosts = true
generateResolvConf = true

[user]
default = $USER
EOF
    echo "wsl.conf configured (restart WSL to apply: wsl --shutdown)"
}

# .wslconfig (Windows-side)
configure_wslconfig() {
    local win_home
    win_home="$(wslpath "$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')" 2>/dev/null || echo "")"

    if [[ -z "$win_home" || ! -d "$win_home" ]]; then
        echo "Could not detect Windows home, skipping .wslconfig"
        return 0
    fi

    local wslconfig="$win_home/.wslconfig"
    if [[ -f "$wslconfig" ]]; then
        echo ".wslconfig already exists at $wslconfig"
        return 0
    fi

    cat > "$wslconfig" << 'EOF'
# WSL2 Configuration (restart WSL to apply: wsl --shutdown)

[wsl2]
# memory=8GB
# processors=4
nestedVirtualization=true

[experimental]
autoMemoryReclaim=gradual
sparseVhd=true
EOF
    echo ".wslconfig created at $wslconfig"
}

configure_windows_interop() {
    if cmd.exe /d /c exit &>/dev/null; then
        echo "Windows executable interop is working"
        return 0
    fi

    if [[ ! -d /etc/binfmt.d || ! -e /proc/sys/fs/binfmt_misc/register ]]; then
        echo "Windows executable interop is unavailable and binfmt_misc is not ready" >&2
        return 1
    fi

    echo "Registering the WSL Windows executable format with systemd-binfmt..."
    printf '%s\n' ':WSLInterop:M::MZ::/init:P' \
        | sudo tee /etc/binfmt.d/WSLInterop.conf >/dev/null
    sudo systemctl restart systemd-binfmt.service

    cmd.exe /d /c exit &>/dev/null || {
        echo "WSLInterop registration completed but Windows executables still cannot run" >&2
        return 1
    }
    echo "Windows executable interop repaired"
}

configure_wsl_conf
configure_windows_interop
configure_wslconfig

echo "WSL setup complete. Run 'wsl --shutdown' in Windows Terminal to apply."
