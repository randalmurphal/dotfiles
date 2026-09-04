#!/usr/bin/env bash
set -euo pipefail

install_rust() {
    if command -v rustc &>/dev/null; then
        local version
        version="$(rustc --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
        echo "Rust already installed ($version), updating..."
        rustup update stable
        return 0
    fi

    echo "Installing Rust via rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable

    source "$HOME/.cargo/env" 2>/dev/null || true

    if command -v rustc &>/dev/null; then
        echo "Rust $(rustc --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+') installed"
    else
        echo "Rust installation failed"
        return 1
    fi

    rustup component add clippy rustfmt rust-analyzer
    echo "Rust setup complete."
}

install_rust
