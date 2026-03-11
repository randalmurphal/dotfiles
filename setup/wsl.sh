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

# Git WSL optimizations
configure_git_wsl() {
    if command -v git &>/dev/null; then
        git config --global core.fscache true
        git config --global core.preloadindex true
        git config --global core.untrackedCache true
        git config --global core.checkStat minimal
        echo "Git WSL optimizations applied"
    fi
}

configure_wsl_conf
configure_wslconfig
configure_git_wsl

echo "WSL setup complete. Run 'wsl --shutdown' in Windows Terminal to apply."
