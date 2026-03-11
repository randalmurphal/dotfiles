#!/usr/bin/env bash
set -euo pipefail

PYTHON_VERSION="${PYTHON_VERSION:-3.12}"

install_pyenv() {
    if [[ -d "$HOME/.pyenv" ]]; then
        echo "pyenv already installed"
        return 0
    fi

    echo "Installing pyenv..."

    # Install build dependencies
    if command -v apt-get &>/dev/null; then
        sudo apt-get install -y -qq \
            build-essential libssl-dev libbz2-dev libreadline-dev \
            libsqlite3-dev zlib1g-dev liblzma-dev libffi-dev \
            tk-dev libncursesw5-dev libxml2-dev libxmlsec1-dev 2>/dev/null || true
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y gcc zlib-devel bzip2-devel readline-devel \
            sqlite-devel openssl-devel libffi-devel 2>/dev/null || true
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm --needed base-devel openssl zlib xz 2>/dev/null || true
    elif command -v zypper &>/dev/null; then
        sudo zypper install -y gcc make zlib-devel libbz2-devel readline-devel \
            sqlite3-devel libopenssl-devel libffi-devel 2>/dev/null || true
    fi

    curl https://pyenv.run | bash

    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
}

install_python() {
    install_pyenv

    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"

    # Install Python version
    if pyenv versions --bare | grep -q "^${PYTHON_VERSION}"; then
        echo "Python $PYTHON_VERSION already installed"
    else
        echo "Installing Python $PYTHON_VERSION..."
        pyenv install "$PYTHON_VERSION"
    fi

    pyenv global "$PYTHON_VERSION"
    echo "Python $(pyenv exec python --version) set as default"

    # Install global packages
    echo "Installing global Python packages..."
    pyenv exec pip install --upgrade pip 2>/dev/null
    for pkg in pipx uv ruff; do
        pyenv exec pip install --upgrade "$pkg" 2>/dev/null || echo "  Warning: failed to install $pkg"
    done

    echo "Python setup complete."
}

install_python
