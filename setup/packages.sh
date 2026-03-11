#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Common packages (names vary by distro - handle inline)
install_packages() {
    echo "Installing system packages..."

    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS: use Brewfile
        if ! command -v brew &>/dev/null; then
            echo "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        brew bundle --file="$DOTFILES_DIR/Brewfile" --no-lock

    elif command -v apt-get &>/dev/null; then
        sudo apt-get update -qq
        sudo apt-get install -y -qq \
            git curl wget unzip jq tree make stow \
            zsh tmux neovim \
            fzf zoxide ripgrep fd-find \
            bat eza htop btop ncdu \
            build-essential python3-venv python3-dev python3-pip \
            xclip git-delta gh lazygit direnv 2>/dev/null || true

    elif command -v dnf &>/dev/null; then
        sudo dnf install -y \
            git curl wget unzip jq tree make stow \
            zsh tmux neovim \
            fzf zoxide ripgrep fd-find \
            bat eza htop btop ncdu \
            gcc gcc-c++ python3-devel \
            xclip git-delta gh lazygit direnv 2>/dev/null || true

    elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm --needed \
            git curl wget unzip jq tree make stow \
            zsh tmux neovim \
            fzf zoxide ripgrep fd \
            bat eza htop btop ncdu \
            base-devel python python-pip \
            xclip git-delta github-cli lazygit direnv 2>/dev/null || true

    elif command -v zypper &>/dev/null; then
        sudo zypper install -y \
            git curl wget unzip jq tree make stow \
            zsh tmux neovim \
            fzf zoxide ripgrep fd \
            bat htop btop ncdu \
            gcc make python3-devel \
            xclip git-delta gh lazygit direnv 2>/dev/null || true
    else
        echo "Unsupported package manager. Install packages manually."
        return 1
    fi

    echo "Packages installed."
}

install_packages
