#!/usr/bin/env bash
set -euo pipefail

PYTHON_VERSION="${PYTHON_VERSION:-3.13}"

install_uv() {
    if command -v uv &>/dev/null; then
        echo "uv already installed ($(uv --version))"
        return 0
    fi

    echo "Installing uv from Astral's standalone installer..."
    local installer
    installer="$(mktemp)"
    trap 'rm -f "$installer"' RETURN
    curl -LsSf https://astral.sh/uv/install.sh -o "$installer"
    UV_INSTALL_DIR="$HOME/.local/bin" UV_NO_MODIFY_PATH=1 sh "$installer"
    trap - RETURN
    rm -f "$installer"
    export PATH="$HOME/.local/bin:$PATH"
    command -v uv &>/dev/null || {
        echo "uv installation did not produce an executable on PATH" >&2
        return 1
    }
}

install_python() {
    install_uv

    echo "Installing managed Python $PYTHON_VERSION..."
    uv python install "$PYTHON_VERSION"
    echo "$(uv --version) with $(uv python find "$PYTHON_VERSION")"

    echo "Python setup complete."
}

install_python
