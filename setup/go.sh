#!/usr/bin/env bash
set -euo pipefail

GO_VERSION="${GO_VERSION:-latest}"

install_go() {
    local version="$GO_VERSION"

    if [[ "$version" == "latest" ]]; then
        version=$(curl -fsSL "https://go.dev/VERSION?m=text" 2>/dev/null | head -1)
        if [[ -z "$version" ]]; then
            echo "Failed to determine latest Go version"
            return 1
        fi
    fi
    [[ "$version" != go* ]] && version="go${version}"

    # Check current version
    if command -v go &>/dev/null; then
        local current
        current="$(go version 2>/dev/null | grep -oE 'go[0-9]+\.[0-9]+(\.[0-9]+)?')"
        if [[ "$current" == "$version" ]]; then
            echo "Go $version already installed"
            return 0
        fi
    fi

    # Determine platform
    local arch os
    case "$(uname -m)" in
        x86_64)       arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        *) echo "Unsupported architecture: $(uname -m)"; return 1 ;;
    esac
    case "$(uname -s)" in
        Linux)  os="linux" ;;
        Darwin) os="darwin" ;;
        *) echo "Unsupported OS: $(uname -s)"; return 1 ;;
    esac

    local tarball="${version}.${os}-${arch}.tar.gz"
    local url="https://go.dev/dl/${tarball}"

    echo "Installing $version..."
    local tmpdir
    tmpdir="$(mktemp -d)"
    curl -fsSL "$url" -o "$tmpdir/$tarball"

    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf "$tmpdir/$tarball"
    rm -rf "$tmpdir"

    export PATH="/usr/local/go/bin:$PATH"
    mkdir -p "$HOME/go/bin"

    echo "$(go version) installed"
}

install_go
