#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Building sysinfo-daemon..."
cd "$SCRIPT_DIR"
cargo build --release

echo "Installing binary..."
mkdir -p ~/.local/bin
cp target/release/sysinfo-daemon ~/.local/bin/

# Platform-specific service installation
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Installing launchd agent..."
    mkdir -p ~/Library/LaunchAgents
    sed "s|__HOME__|$HOME|g" com.user.sysinfo-daemon.plist > ~/Library/LaunchAgents/com.user.sysinfo-daemon.plist

    echo "Loading agent..."
    launchctl bootout "gui/$(id -u)/com.user.sysinfo-daemon" 2>/dev/null || true
    launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/com.user.sysinfo-daemon.plist
else
    echo "Installing systemd service..."
    mkdir -p ~/.config/systemd/user
    cp sysinfo.service ~/.config/systemd/user/

    echo "Enabling and starting service..."
    systemctl --user daemon-reload
    systemctl --user enable --now sysinfo
fi

echo "Verifying..."
sleep 0.5
cat /tmp/sysinfo

echo ""
echo "Done! sysinfo-daemon is running."
