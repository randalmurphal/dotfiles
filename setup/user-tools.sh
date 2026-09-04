#!/usr/bin/env bash
# User-local tools the distro repositories lack (RHEL-family in particular),
# installed from each project's own release into ~/.local/bin. Linux only:
# every archive below is a Linux build, and on macOS the Brewfile carries
# the same tools.
set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
    echo "User tools are Linux-only here; on macOS run: brew bundle --file=Brewfile"
    exit 0
fi

mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

install_zoxide() {
    if command -v zoxide &>/dev/null; then
        echo "zoxide already installed ($(zoxide --version))"
        return 0
    fi

    echo "Installing zoxide from its official release installer..."
    local installer
    installer="$(mktemp)"
    trap 'rm -f "$installer"' RETURN
    curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh \
        -o "$installer"
    sh "$installer"
    trap - RETURN
    rm -f "$installer"
}

install_lazygit() {
    if command -v lazygit &>/dev/null; then
        echo "lazygit already installed ($(lazygit --version | head -1))"
        return 0
    fi

    local arch version
    case "$(uname -m)" in
        x86_64) arch="x86_64" ;;
        aarch64|arm64) arch="arm64" ;;
        *)
            echo "Unsupported architecture for lazygit: $(uname -m)" >&2
            return 1
            ;;
    esac

    version="$(
        curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest \
            | jq -er '.tag_name | ltrimstr("v")'
    )"

    echo "Installing lazygit $version from its official release..."
    (
        local tmpdir archive
        tmpdir="$(mktemp -d)"
        trap 'rm -rf "$tmpdir"' EXIT
        archive="$tmpdir/lazygit.tar.gz"
        curl -fsSL \
            "https://github.com/jesseduffield/lazygit/releases/download/v${version}/lazygit_${version}_Linux_${arch}.tar.gz" \
            -o "$archive"
        tar -xzf "$archive" -C "$tmpdir" lazygit
        install -Dm755 "$tmpdir/lazygit" "$HOME/.local/bin/lazygit"
    )
}

install_delta() {
    if command -v delta &>/dev/null; then
        echo "delta already installed ($(delta --version))"
        return 0
    fi

    local arch version
    case "$(uname -m)" in
        x86_64) arch="x86_64-unknown-linux-gnu" ;;
        aarch64|arm64) arch="aarch64-unknown-linux-gnu" ;;
        *)
            echo "Unsupported architecture for delta: $(uname -m)" >&2
            return 1
            ;;
    esac

    version="$(
        curl -fsSL https://api.github.com/repos/dandavison/delta/releases/latest \
            | jq -er '.tag_name | ltrimstr("v")'
    )"

    echo "Installing delta $version from its official release..."
    (
        local tmpdir archive delta_bin
        tmpdir="$(mktemp -d)"
        trap 'rm -rf "$tmpdir"' EXIT
        archive="$tmpdir/delta.tar.gz"
        curl -fsSL \
            "https://github.com/dandavison/delta/releases/download/${version}/delta-${version}-${arch}.tar.gz" \
            -o "$archive"
        tar -xzf "$archive" -C "$tmpdir"
        delta_bin="$(find "$tmpdir" -type f -name delta -perm -u+x -print -quit)"
        if [[ -z "$delta_bin" ]]; then
            echo "The delta release archive did not contain an executable" >&2
            return 1
        fi
        install -Dm755 "$delta_bin" "$HOME/.local/bin/delta"
    )
}

install_eza() {
    if command -v eza &>/dev/null; then
        echo "eza already installed ($(eza --version | head -1))"
        return 0
    fi

    local arch version
    case "$(uname -m)" in
        x86_64) arch="x86_64-unknown-linux-gnu" ;;
        aarch64|arm64) arch="aarch64-unknown-linux-gnu" ;;
        *)
            echo "Unsupported architecture for eza: $(uname -m)" >&2
            return 1
            ;;
    esac

    version="$(
        curl -fsSL https://api.github.com/repos/eza-community/eza/releases/latest \
            | jq -er '.tag_name | ltrimstr("v")'
    )"

    echo "Installing eza $version from its official release..."
    (
        local tmpdir archive
        tmpdir="$(mktemp -d)"
        trap 'rm -rf "$tmpdir"' EXIT
        archive="$tmpdir/eza.tar.gz"
        curl -fsSL \
            "https://github.com/eza-community/eza/releases/download/v${version}/eza_${arch}.tar.gz" \
            -o "$archive"
        tar -xzf "$archive" -C "$tmpdir"
        install -Dm755 "$tmpdir/eza" "$HOME/.local/bin/eza"
    )
}

install_direnv() {
    if command -v direnv &>/dev/null; then
        echo "direnv already installed ($(direnv version))"
        return 0
    fi

    local arch version
    case "$(uname -m)" in
        x86_64) arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        *)
            echo "Unsupported architecture for direnv: $(uname -m)" >&2
            return 1
            ;;
    esac

    version="$(
        curl -fsSL https://api.github.com/repos/direnv/direnv/releases/latest \
            | jq -er '.tag_name | ltrimstr("v")'
    )"

    echo "Installing direnv $version from its official release..."
    curl -fsSL \
        "https://github.com/direnv/direnv/releases/download/v${version}/direnv.linux-${arch}" \
        -o "$HOME/.local/bin/direnv"
    chmod 0755 "$HOME/.local/bin/direnv"
}

install_bun() {
    if [[ -x "$HOME/.bun/bin/bun" ]]; then
        echo "Bun already installed ($("$HOME/.bun/bin/bun" --version))"
        return 0
    fi

    local asset version
    case "$(uname -m)" in
        x86_64) asset="bun-linux-x64" ;;
        aarch64|arm64) asset="bun-linux-aarch64" ;;
        *)
            echo "Unsupported architecture for Bun: $(uname -m)" >&2
            return 1
            ;;
    esac

    version="$(
        curl -fsSL https://api.github.com/repos/oven-sh/bun/releases/latest \
            | jq -er '.tag_name'
    )"

    echo "Installing Bun ${version#bun-v} from its official release..."
    (
        local tmpdir archive
        tmpdir="$(mktemp -d)"
        trap 'rm -rf "$tmpdir"' EXIT
        archive="$tmpdir/bun.zip"
        curl -fsSL \
            "https://github.com/oven-sh/bun/releases/download/${version}/${asset}.zip" \
            -o "$archive"
        unzip -q "$archive" -d "$tmpdir"
        install -Dm755 "$tmpdir/$asset/bun" "$HOME/.bun/bin/bun"
        ln -s bun "$HOME/.bun/bin/bunx"
    )
}

install_zoxide
install_lazygit
install_delta
install_eza
install_direnv
install_bun

echo "User tools setup complete."
