#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

warn_optional() {
    printf 'Warning: optional package %s could not be installed.\n' "$1" >&2
}

install_optional_apt_packages() {
    local package
    for package in "$@"; do
        sudo apt-get install -y -qq "$package" || warn_optional "$package"
    done
}

install_optional_dnf_packages() {
    local package
    for package in "$@"; do
        sudo dnf install -y "$package" || warn_optional "$package"
    done
}

install_optional_pacman_packages() {
    local package
    for package in "$@"; do
        sudo pacman -S --noconfirm --needed "$package" || warn_optional "$package"
    done
}

install_optional_zypper_packages() {
    local package
    for package in "$@"; do
        sudo zypper install -y "$package" || warn_optional "$package"
    done
}

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
            fzf ripgrep fd-find \
            bat htop ncdu \
            build-essential python3-venv python3-dev python3-pip libpq-dev \
            xclip gh direnv \
            clang cmake lld nasm \
            strace lsof psmisc inotify-tools rsync zip bash-completion \
            postgresql-client
        install_optional_apt_packages zoxide eza btop git-delta lazygit tldr
        # pyodbc (m32rimm fisio) builds against unixODBC.
        install_optional_apt_packages unixodbc unixodbc-dev

    elif command -v dnf &>/dev/null; then
        local distro_id="unknown"
        if [[ -r /etc/os-release ]]; then
            distro_id="$(. /etc/os-release && printf '%s' "${ID:-unknown}")"
        fi

        # RHEL-compatible distributions publish most developer utilities in EPEL.
        # Fedora already carries them in its standard repositories.
        if [[ "$distro_id" != "fedora" ]]; then
            sudo dnf install -y epel-release
        fi
        sudo dnf install -y \
            git curl wget unzip jq tree make stow \
            zsh tmux neovim \
            fzf ripgrep fd-find \
            bat htop btop ncdu \
            gcc gcc-c++ python3-devel libpq-devel \
            xclip gh \
            podman podman-docker podman-compose buildah \
            gtk4-devel webkitgtk6.0-devel pkgconf-pkg-config \
            clang cmake lld nasm \
            strace lsof psmisc inotify-tools rsync zip bash-completion \
            postgresql
        install_optional_dnf_packages zoxide eza lazygit direnv tldr
        # pyodbc (m32rimm fisio) builds against unixODBC.
        install_optional_dnf_packages unixODBC unixODBC-devel

    elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm --needed \
            git curl wget unzip jq tree make stow \
            zsh tmux neovim \
            fzf zoxide ripgrep fd \
            bat eza htop btop ncdu \
            base-devel python python-pip \
            xclip github-cli direnv \
            clang cmake lld nasm \
            strace lsof psmisc inotify-tools rsync zip bash-completion \
            postgresql
        install_optional_pacman_packages git-delta lazygit tldr

    elif command -v zypper &>/dev/null; then
        sudo zypper install -y \
            git curl wget unzip jq tree make stow \
            zsh tmux neovim \
            fzf zoxide ripgrep fd \
            bat htop btop ncdu \
            gcc make python3-devel \
            xclip gh direnv \
            clang cmake lld nasm \
            strace lsof psmisc inotify-tools rsync zip bash-completion \
            postgresql
        install_optional_zypper_packages git-delta lazygit eza tealdeer
    else
        echo "Unsupported package manager. Install packages manually."
        return 1
    fi

    echo "Packages installed."
}

install_packages
