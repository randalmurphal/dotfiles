#!/usr/bin/env bash
set -euo pipefail

NODE_VERSION="${NODE_VERSION:-lts}"

install_node() {
    local nvm_dir="$HOME/.nvm"

    if [[ ! -s "$nvm_dir/nvm.sh" ]]; then
        echo "Installing nvm..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    fi

    export NVM_DIR="$nvm_dir"
    \. "$nvm_dir/nvm.sh"

    local node_arg="$NODE_VERSION"
    [[ "$node_arg" == "lts" ]] && node_arg="--lts"
    [[ "$node_arg" == "latest" ]] && node_arg="node"

    echo "Installing Node.js ($NODE_VERSION)..."
    nvm install "$node_arg"
    nvm alias default "$node_arg"

    echo "Node.js $(node --version) installed"

    # Global packages
    echo "Installing global npm packages..."
    for pkg in typescript ts-node pnpm yarn; do
        npm install -g "$pkg" 2>/dev/null || echo "  Warning: failed to install $pkg"
    done

    echo "Node.js setup complete."
}

install_node
