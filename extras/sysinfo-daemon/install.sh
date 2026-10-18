#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Building sysinfo-daemon..."
cd "$SCRIPT_DIR"
cargo build --release

echo "Installing binary..."
mkdir -p ~/.local/bin
# Rename into place: copying over the running daemon fails with "Text file busy".
cp target/release/sysinfo-daemon ~/.local/bin/sysinfo-daemon.new
mv -f ~/.local/bin/sysinfo-daemon.new ~/.local/bin/sysinfo-daemon

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
    systemctl --user enable sysinfo
    # restart, not start: a rerun must swap in the binary just installed.
    systemctl --user restart sysinfo
fi

echo "Verifying..."
for _ in $(seq 1 50); do
    [[ -s /tmp/sysinfo ]] && break
    sleep 0.1
done
cat /tmp/sysinfo

echo ""
echo "Done! sysinfo-daemon is running."
