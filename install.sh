#!/usr/bin/env bash
# install.sh - Single entry point for dotfiles installation
# Uses GNU Stow for symlinking, supports Linux (apt/dnf/pacman/zypper) and macOS (brew)
set -uo pipefail

# ─── Bash version check ──────────────────────────────────────────────────────

if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
    printf 'Error: Bash 4+ is required (you have %s).\n' "$BASH_VERSION" >&2
    printf 'On macOS: brew install bash, then re-run with /opt/homebrew/bin/bash install.sh\n' >&2
    exit 1
fi

# ─── Constants ────────────────────────────────────────────────────────────────

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
ALL_MODE=0
SECTION_MODE=0
declare -a SELECTED_SECTIONS=()
declare -A RESULTS  # section -> "installed" | "skipped" | "failed"
WARNINGS=()

# ─── Colors & UI ─────────────────────────────────────────────────────────────

if [[ -t 1 ]]; then
    C_RESET='\033[0m'
    C_BOLD='\033[1m'
    C_DIM='\033[2m'
    C_RED='\033[0;31m'
    C_GREEN='\033[0;32m'
    C_YELLOW='\033[0;33m'
    C_BLUE='\033[0;34m'
    C_PURPLE='\033[0;35m'
    C_CYAN='\033[0;36m'
else
    C_RESET='' C_BOLD='' C_DIM='' C_RED='' C_GREEN=''
    C_YELLOW='' C_BLUE='' C_PURPLE='' C_CYAN=''
fi

info()    { printf "${C_CYAN}  ℹ ${C_RESET}%s\n" "$*"; }
success() { printf "${C_GREEN}  ✔ ${C_RESET}%s\n" "$*"; }
warn()    { printf "${C_YELLOW}  ⚠ ${C_RESET}%s\n" "$*"; WARNINGS+=("$*"); }
error()   { printf "${C_RED}  ✖ ${C_RESET}%s\n" "$*" >&2; }
step()    { printf "${C_BLUE}  → ${C_RESET}%s\n" "$*"; }

section() {
    printf '\n'
    printf "${C_CYAN}${C_BOLD}  ── %s ──${C_RESET}\n" "$*"
    printf '\n'
}

# ─── Platform detection ──────────────────────────────────────────────────────

detect_platform() {
    IS_WSL=0
    if [[ -f /proc/version ]] && grep -qi microsoft /proc/version 2>/dev/null; then
        IS_WSL=1
    fi

    case "$(uname -s)" in
        Darwin) DOTFILES_OS="macos" ;;
        Linux)
            if [[ -f /etc/os-release ]]; then
                local id
                id="$(. /etc/os-release && echo "${ID:-unknown}")"
                case "$id" in
                    ubuntu|debian|pop|linuxmint) DOTFILES_OS="debian" ;;
                    fedora|rhel|centos|rocky|alma|almalinux) DOTFILES_OS="fedora" ;;
                    arch|manjaro|endeavouros) DOTFILES_OS="arch" ;;
                    opensuse*|sles) DOTFILES_OS="opensuse" ;;
                    *) DOTFILES_OS="$id" ;;
                esac
            else
                DOTFILES_OS="unknown"
            fi
            ;;
        *) DOTFILES_OS="unknown" ;;
    esac

    case "$(uname -m)" in
        x86_64|amd64) DOTFILES_ARCH="amd64" ;;
        aarch64|arm64) DOTFILES_ARCH="arm64" ;;
        *) DOTFILES_ARCH="$(uname -m)" ;;
    esac
}

platform_pretty() {
    local name=""
    case "$DOTFILES_OS" in
        macos) name="macOS" ;;
        debian)
            if [[ -f /etc/os-release ]]; then
                name="$(. /etc/os-release && echo "${PRETTY_NAME:-Debian-based}")"
            else
                name="Debian-based"
            fi
            ;;
        fedora) name="$(. /etc/os-release && echo "${PRETTY_NAME:-Fedora}")" ;;
        arch)   name="$(. /etc/os-release && echo "${PRETTY_NAME:-Arch Linux}")" ;;
        opensuse) name="$(. /etc/os-release && echo "${PRETTY_NAME:-openSUSE}")" ;;
        *) name="$DOTFILES_OS" ;;
    esac
    if [[ "$IS_WSL" -eq 1 ]]; then
        name="$name (WSL2)"
    fi
    printf '%s / %s' "$name" "$DOTFILES_ARCH"
}

# ─── Helpers ─────────────────────────────────────────────────────────────────

command_exists() { command -v "$1" &>/dev/null; }

confirm() {
    if [[ "$ALL_MODE" -eq 1 ]]; then
        return 0
    fi
    local prompt="$1"
    local reply
    printf "  ${C_PURPLE}[Y/n]${C_RESET} %s " "$prompt"
    read -r reply
    case "$reply" in
        [nN]*) return 1 ;;
        *) return 0 ;;
    esac
}

ensure_stow() {
    if command_exists stow; then
        return 0
    fi
    step "Installing stow..."
    case "$DOTFILES_OS" in
        debian)  sudo apt-get update -qq && sudo apt-get install -y -qq stow ;;
        fedora)  sudo dnf install -y -q stow ;;
        arch)    sudo pacman -S --noconfirm --needed stow ;;
        opensuse) sudo zypper install -y stow ;;
        macos)   brew install stow ;;
        *)
            error "Cannot install stow automatically on $DOTFILES_OS"
            return 1
            ;;
    esac
}

stow_package() {
    local pkg="$1"
    local target="${2:-$HOME}"
    local pkg_dir="$DOTFILES_DIR/$pkg"

    if [[ ! -d "$pkg_dir" ]]; then
        warn "Stow package '$pkg' not found at $pkg_dir"
        return 1
    fi

    ensure_stow || return 1

    # Dry-run to find conflicts
    local conflicts
    if ! conflicts="$(stow --dir="$DOTFILES_DIR" --target="$target" --no-folding --simulate 2>&1 "$pkg")"; then
        # Extract conflicting paths from stow error output
        # Stow reports conflicts as:
        #   "existing target is not owned by stow: <path>"
        #   "existing target is neither a link nor a directory: <path>"
        local conflict_files
        conflict_files="$(echo "$conflicts" \
            | grep -E 'existing target is (not owned by stow|neither a link nor a directory):' \
            | sed 's/.*existing target is [^:]*: //' \
            | sed 's/^[[:space:]]*//' \
            || true)"

        if [[ -n "$conflict_files" ]]; then
            mkdir -p "$BACKUP_DIR"
            while IFS= read -r f; do
                [[ -z "$f" ]] && continue
                local full_path="$target/$f"
                if [[ -L "$full_path" ]]; then
                    # Symlink pointing elsewhere (e.g., old system-configs) — remove it
                    local link_target
                    link_target="$(readlink "$full_path")"
                    rm "$full_path"
                    info "Removed stale symlink $full_path → $link_target"
                elif [[ -e "$full_path" ]]; then
                    # Real file — back it up
                    local backup_path="$BACKUP_DIR/$f"
                    mkdir -p "$(dirname "$backup_path")"
                    mv "$full_path" "$backup_path"
                    info "Backed up $full_path → $backup_path"
                fi
            done <<< "$conflict_files"
        fi
    fi

    if stow --dir="$DOTFILES_DIR" --restow --no-folding --target="$target" "$pkg" 2>&1; then
        success "Stowed $pkg → $target"
        return 0
    else
        error "Failed to stow $pkg"
        return 1
    fi
}

# ─── Install sections ────────────────────────────────────────────────────────

install_section_packages() {
    section "System Packages"
    local script="$DOTFILES_DIR/setup/packages.sh"
    if [[ -f "$script" ]]; then
        if bash "$script"; then
            success "System packages installed"
        else
            error "System package installation failed"
            return 1
        fi
    else
        error "setup/packages.sh not found"
        return 1
    fi
}

install_section_tools() {
    section "User Tools"
    stow_package bin || return 1

    local script="$DOTFILES_DIR/setup/user-tools.sh"
    if [[ -f "$script" ]]; then
        if bash "$script"; then
            success "User tools installed"
        else
            error "User tool installation failed"
            return 1
        fi
    else
        error "setup/user-tools.sh not found"
        return 1
    fi
}

install_section_shell() {
    section "Shell"

    # Create ~/.zsh as a real directory so stow creates per-file symlinks
    # (prevents stow from folding the whole dir into one symlink)
    mkdir -p "$HOME/.zsh"

    stow_package shell || return 1

    # oh-my-zsh
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        info "oh-my-zsh already installed"
    else
        step "Installing oh-my-zsh..."
        RUNZSH=no KEEP_ZSHRC=yes sh -c \
            "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || {
            error "oh-my-zsh installation failed"
            return 1
        }
    fi

    # Plugins
    local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

    if [[ -d "$zsh_custom/plugins/zsh-autosuggestions" ]]; then
        info "zsh-autosuggestions already installed"
    else
        step "Installing zsh-autosuggestions..."
        git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions \
            "$zsh_custom/plugins/zsh-autosuggestions" || return 1
    fi

    if [[ -d "$zsh_custom/plugins/zsh-syntax-highlighting" ]]; then
        info "zsh-syntax-highlighting already installed"
    else
        step "Installing zsh-syntax-highlighting..."
        git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting \
            "$zsh_custom/plugins/zsh-syntax-highlighting" || return 1
    fi

    # Local zsh config template (lives alongside stow symlinks, not tracked)
    local local_zsh="$HOME/.zsh/local.zsh"
    if [[ ! -f "$local_zsh" ]]; then
        cat > "$local_zsh" << 'LOCALZSH'
# ~/.zsh/local.zsh - Machine-specific ZSH configuration
# This file is NOT managed by stow and is gitignored.
# Add machine-specific aliases, exports, paths, etc. here.

# Example:
# export WORK_DIR="$HOME/projects"
# alias deploy='./scripts/deploy.sh'
LOCALZSH
        success "Created $local_zsh template"
    else
        info "$local_zsh already exists"
    fi

    success "Shell setup complete"
}

install_section_git() {
    section "Git"

    stow_package git || return 1

    # gitconfig.local
    local gitconfig_local="$HOME/.gitconfig.local"
    if [[ -f "$gitconfig_local" ]]; then
        info "$gitconfig_local already exists"
    else
        step "Setting up Git identity..."
        local git_name="" git_email=""
        if [[ "$ALL_MODE" -eq 1 ]]; then
            warn "Skipping gitconfig.local setup in --all mode (no interactive prompts)"
        else
            printf "    Name:  "
            read -r git_name
            printf "    Email: "
            read -r git_email
            if [[ -n "$git_name" && -n "$git_email" ]]; then
                cat > "$gitconfig_local" << EOF
[user]
    name = $git_name
    email = $git_email
EOF
                success "Created $gitconfig_local"
            else
                warn "Skipped gitconfig.local (empty name or email)"
            fi
        fi
    fi

    # SSH key
    local ssh_key="$HOME/.ssh/id_ed25519"
    if [[ -f "$ssh_key" ]]; then
        info "SSH key already exists at $ssh_key"
    else
        step "Generating SSH key..."
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
        local email=""
        if [[ -f "$HOME/.gitconfig.local" ]]; then
            email="$(git config --file "$HOME/.gitconfig.local" user.email 2>/dev/null || true)"
        fi
        ssh-keygen -t ed25519 -C "${email:-dotfiles}" -f "$ssh_key" -N ""
        success "SSH key generated"
        printf '\n'
        info "Public key:"
        printf '    %s\n' "$(cat "${ssh_key}.pub")"
        printf '\n'
    fi

    success "Git setup complete"
}

install_section_tmux() {
    section "Tmux"

    stow_package tmux || return 1

    local tpm_dir="$HOME/.tmux/plugins/tpm"
    if [[ -d "$tpm_dir" ]]; then
        info "TPM already installed"
    else
        step "Installing TPM..."
        git clone --depth 1 https://github.com/tmux-plugins/tpm "$tpm_dir" || return 1
        success "TPM installed"
    fi

    success "Tmux setup complete"
}

install_section_wezterm() {
    section "WezTerm"

    stow_package wezterm || return 1

    if [[ "$IS_WSL" -eq 1 ]]; then
        step "Copying WezTerm config to Windows side..."
        local win_home
        win_home="$(cmd.exe /C 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')" || true
        if [[ -n "$win_home" ]]; then
            # Convert Windows path to WSL path
            local wsl_win_home
            wsl_win_home="$(wslpath -u "$win_home" 2>/dev/null || true)"
            if [[ -n "$wsl_win_home" && -d "$wsl_win_home" ]]; then
                local src="$DOTFILES_DIR/wezterm/.wezterm.lua"
                if [[ -f "$src" ]]; then
                    cp "$src" "$wsl_win_home/.wezterm.lua"
                    success "Copied .wezterm.lua to $wsl_win_home"
                else
                    warn "wezterm/.wezterm.lua not found in stow package"
                fi
            else
                warn "Could not resolve Windows home directory"
            fi
        else
            warn "Could not detect Windows USERPROFILE"
        fi
    fi

    success "WezTerm setup complete"
}

install_section_python() {
    section "Python"
    local script="$DOTFILES_DIR/setup/python.sh"
    if [[ -f "$script" ]]; then
        if bash "$script"; then
            success "Python setup complete"
        else
            error "Python setup failed"
            return 1
        fi
    else
        error "setup/python.sh not found"
        return 1
    fi
}

install_section_node() {
    section "Node.js"
    local script="$DOTFILES_DIR/setup/node.sh"
    if [[ -f "$script" ]]; then
        if bash "$script"; then
            success "Node.js setup complete"
        else
            error "Node.js setup failed"
            return 1
        fi
    else
        error "setup/node.sh not found"
        return 1
    fi
}

install_section_go() {
    section "Go"
    local script="$DOTFILES_DIR/setup/go.sh"
    if [[ -f "$script" ]]; then
        if bash "$script"; then
            success "Go setup complete"
        else
            error "Go setup failed"
            return 1
        fi
    else
        error "setup/go.sh not found"
        return 1
    fi
}

install_section_rust() {
    section "Rust"
    local script="$DOTFILES_DIR/setup/rust.sh"
    if [[ -f "$script" ]]; then
        if bash "$script"; then
            success "Rust setup complete"
        else
            error "Rust setup failed"
            return 1
        fi
    else
        error "setup/rust.sh not found"
        return 1
    fi
}

# Neovim's latest release into ~/.local/opt/nvim-<tag>, with ~/.local/opt/nvim
# and ~/.local/bin/nvim pointing at it. Rerunning upgrades to a newer release.
install_neovim_release() {
    local arch tag opt="$HOME/.local/opt"
    case "$(uname -m)" in
        x86_64) arch="x86_64" ;;
        aarch64|arm64) arch="arm64" ;;
        *) error "Unsupported architecture for Neovim: $(uname -m)"; return 1 ;;
    esac

    tag="$(curl -fsSL https://api.github.com/repos/neovim/neovim/releases/latest | jq -er '.tag_name')" || {
        error "Could not look up the latest Neovim release"
        return 1
    }

    if [[ -x "$opt/nvim-$tag/bin/nvim" ]]; then
        info "Neovim $tag already installed"
    else
        step "Installing Neovim $tag from its official release..."
        local tmpdir
        tmpdir="$(mktemp -d)"
        if ! curl -fsSL "https://github.com/neovim/neovim/releases/download/$tag/nvim-linux-$arch.tar.gz" \
                | tar -xz -C "$tmpdir"; then
            rm -rf "$tmpdir"
            error "Neovim $tag download failed"
            return 1
        fi
        mkdir -p "$opt"
        mv "$tmpdir/nvim-linux-$arch" "$opt/nvim-$tag"
        rm -rf "$tmpdir"
    fi

    mkdir -p "$HOME/.local/bin"
    ln -sfn "nvim-$tag" "$opt/nvim"
    ln -sfn "$opt/nvim/bin/nvim" "$HOME/.local/bin/nvim"
    find "$opt" -maxdepth 1 -type d -name 'nvim-v*' ! -name "nvim-$tag" -exec rm -rf {} +
    success "Neovim $("$HOME/.local/bin/nvim" --version | head -1)"
}

install_section_neovim() {
    section "Neovim"

    # Install neovim: Homebrew on macOS, the official release everywhere else
    # (distro packages lag by several minor versions).
    if [[ "$DOTFILES_OS" == "macos" ]]; then
        if command_exists nvim; then
            info "Neovim already installed ($(nvim --version | head -1))"
        else
            brew install neovim
        fi
    else
        install_neovim_release || return 1
    fi

    # Clone config
    local nvim_config="$HOME/.config/nvim"
    if [[ -d "$nvim_config" ]]; then
        info "Neovim config already exists at $nvim_config"
    else
        step "Cloning neovim-config..."
        mkdir -p "$HOME/.config"
        git clone https://github.com/randalmurphal/neovim-config.git "$nvim_config"
        success "Neovim config cloned to $nvim_config"
    fi

    success "Neovim setup complete"
}

install_section_claude() {
    section "Claude Code"

    # Install Claude Code CLI via official install script
    if command_exists claude; then
        info "Claude Code CLI already installed"
    else
        step "Installing Claude Code CLI..."
        curl -fsSL https://claude.ai/install.sh | sh || {
            error "Claude Code install failed (try: curl -fsSL https://claude.ai/install.sh | sh)"
            return 1
        }
    fi

    # Clone config repo into ~/.claude
    local claude_dir="$HOME/.claude"
    if [[ -d "$claude_dir/.git" ]]; then
        info "claude-config already cloned at $claude_dir"
    elif [[ -d "$claude_dir" ]]; then
        error "$claude_dir already contains non-Git runtime state"
        error "Refusing to initialize or overwrite it; migrate or reconcile it explicitly"
        return 1
    else
        step "Cloning claude-config..."
        git clone git@github.com:randalmurphal/claude-config.git "$claude_dir" || {
            error "Failed to clone claude-config (SSH key needed for github.com)"
            return 1
        }
    fi

    success "Claude Code setup complete"
}

install_section_codex() {
    section "Codex"

    # Install Codex CLI
    if command_exists codex; then
        info "Codex CLI already installed"
    else
        step "Installing Codex CLI..."
        if command_exists npm; then
            npm install -g @openai/codex || {
                error "Codex install failed (try: npm install -g @openai/codex)"
                return 1
            }
        else
            error "npm not found; cannot install Codex"
            return 1
        fi
    fi

    # Clone config repo into ~/.codex
    local codex_dir="$HOME/.codex"
    if [[ -d "$codex_dir/.git" ]]; then
        info "codex-config already cloned at $codex_dir"
    elif [[ -d "$codex_dir" ]]; then
        error "$codex_dir already contains non-Git runtime state"
        error "Refusing to initialize or overwrite it; migrate or reconcile it explicitly"
        return 1
    else
        step "Cloning codex-config..."
        git clone git@github.com:randalmurphal/codex-config.git "$codex_dir" || {
            error "Failed to clone codex-config (SSH key needed for github.com)"
            return 1
        }
    fi

    success "Codex setup complete"
}

install_section_wsl() {
    section "WSL Setup"
    local script="$DOTFILES_DIR/setup/wsl.sh"
    if [[ -f "$script" ]]; then
        if bash "$script"; then
            success "WSL setup complete"
        else
            error "WSL setup failed"
            return 1
        fi
    else
        error "setup/wsl.sh not found"
        return 1
    fi
}

# ─── Usage ────────────────────────────────────────────────────────────────────

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Dotfiles installer using GNU Stow for symlinking.

Options:
  --all              Install everything without prompting
  --section <name>   Install only the named section (repeatable)
  --help             Show this help message

Sections:
  packages, tools, shell, git, tmux, wezterm, python, node, go, rust,
  neovim, claude, codex, wsl

Examples:
  $(basename "$0")                            # Interactive mode
  $(basename "$0") --all                      # Install everything
  $(basename "$0") --section shell            # Just shell setup
  $(basename "$0") --section shell --section git  # Multiple sections
EOF
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --all)  ALL_MODE=1; shift ;;
            --section)
                if [[ $# -lt 2 ]]; then
                    error "--section requires a section name"
                    usage
                    exit 1
                fi
                SECTION_MODE=1
                SELECTED_SECTIONS+=("$2")
                shift 2
                ;;
            --help) usage; exit 0 ;;
            *)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    if [[ "$ALL_MODE" -eq 1 && "$SECTION_MODE" -eq 1 ]]; then
        error "--all and --section cannot be used together"
        exit 1
    fi

    detect_platform

    # Header
    printf '\n'
    printf "${C_PURPLE}  ┌─────────────────────────────────────┐${C_RESET}\n"
    printf "${C_PURPLE}  │${C_BOLD}         Dotfiles Installer          ${C_RESET}${C_PURPLE}│${C_RESET}\n"
    printf "${C_PURPLE}  │${C_DIM}       github.com/randalmurphal      ${C_RESET}${C_PURPLE}│${C_RESET}\n"
    printf "${C_PURPLE}  └─────────────────────────────────────┘${C_RESET}\n"
    printf '\n'
    printf "  Detected: %s\n" "$(platform_pretty)"
    printf '\n'

    # Define sections: key|label|function|wsl_only
    local -a sections=(
        "packages|System packages|install_section_packages|0"
        "tools|User tools|install_section_tools|0"
        "shell|Shell (zsh + oh-my-zsh)|install_section_shell|0"
        "git|Git configuration|install_section_git|0"
        "tmux|Tmux + TPM|install_section_tmux|0"
        "wezterm|WezTerm|install_section_wezterm|0"
        "python|Python (uv)|install_section_python|0"
        "node|Node.js (nvm)|install_section_node|0"
        "go|Go|install_section_go|0"
        "rust|Rust (rustup)|install_section_rust|0"
        "neovim|Neovim|install_section_neovim|0"
        "claude|Claude Code|install_section_claude|0"
        "codex|Codex|install_section_codex|0"
        "wsl|WSL setup|install_section_wsl|1"
    )

    # Collect user choices
    declare -A choices

    # Build a lookup of valid section keys
    declare -A valid_sections
    for entry in "${sections[@]}"; do
        IFS='|' read -r key label func wsl_only <<< "$entry"
        valid_sections["$key"]=1
    done

    if [[ "$SECTION_MODE" -eq 1 ]]; then
        # Validate requested sections
        for s in "${SELECTED_SECTIONS[@]}"; do
            if [[ -z "${valid_sections[$s]:-}" ]]; then
                error "Unknown section: $s"
                printf "  Valid sections: %s\n" "$(printf '%s ' "${!valid_sections[@]}")" >&2
                exit 1
            fi
        done

        printf "  ${C_BOLD}Mode:${C_RESET} Installing sections: %s\n\n" "${SELECTED_SECTIONS[*]}"
        for s in "${SELECTED_SECTIONS[@]}"; do
            choices["$s"]=1
        done
    elif [[ "$ALL_MODE" -eq 1 ]]; then
        printf "  ${C_BOLD}Mode:${C_RESET} Installing everything (--all)\n\n"
        for entry in "${sections[@]}"; do
            IFS='|' read -r key label func wsl_only <<< "$entry"
            if [[ "$wsl_only" -eq 1 && "$IS_WSL" -eq 0 ]]; then
                continue
            fi
            choices["$key"]=1
        done
    else
        printf "  ${C_BOLD}What would you like to install?${C_RESET}\n\n"
        for entry in "${sections[@]}"; do
            IFS='|' read -r key label func wsl_only <<< "$entry"
            if [[ "$wsl_only" -eq 1 && "$IS_WSL" -eq 0 ]]; then
                continue
            fi
            if confirm "$label"; then
                choices["$key"]=1
            else
                choices["$key"]=0
            fi
        done
    fi

    printf '\n'
    printf "  ${C_CYAN}${C_BOLD}Starting installation...${C_RESET}\n"

    # Run selected sections
    for entry in "${sections[@]}"; do
        IFS='|' read -r key label func wsl_only <<< "$entry"

        if [[ "$wsl_only" -eq 1 && "$IS_WSL" -eq 0 ]]; then
            continue
        fi

        if [[ "${choices[$key]:-0}" -eq 1 ]]; then
            if "$func"; then
                RESULTS["$key"]="installed"
            else
                RESULTS["$key"]="failed"
            fi
        else
            RESULTS["$key"]="skipped"
        fi
    done

    # ── Summary ───────────────────────────────────────────────────────────────

    printf '\n'
    printf "${C_PURPLE}  ┌─────────────────────────────────────┐${C_RESET}\n"
    printf "${C_PURPLE}  │${C_BOLD}             Summary                 ${C_RESET}${C_PURPLE}│${C_RESET}\n"
    printf "${C_PURPLE}  └─────────────────────────────────────┘${C_RESET}\n"
    printf '\n'

    for entry in "${sections[@]}"; do
        IFS='|' read -r key label func wsl_only <<< "$entry"
        if [[ "$wsl_only" -eq 1 && "$IS_WSL" -eq 0 ]]; then
            continue
        fi
        local status="${RESULTS[$key]:-skipped}"
        case "$status" in
            installed) printf "  ${C_GREEN}✔${C_RESET}  %s\n" "$label" ;;
            skipped)   printf "  ${C_DIM}─  %s (skipped)${C_RESET}\n" "$label" ;;
            failed)    printf "  ${C_RED}✖${C_RESET}  %s ${C_RED}(failed)${C_RESET}\n" "$label" ;;
        esac
    done

    if [[ "${#WARNINGS[@]}" -gt 0 ]]; then
        printf '\n'
        printf "  ${C_YELLOW}${C_BOLD}Warnings:${C_RESET}\n"
        for w in "${WARNINGS[@]}"; do
            printf "  ${C_YELLOW}⚠${C_RESET}  %s\n" "$w"
        done
    fi

    printf '\n'

    # Check for any failures
    local has_failures=0
    for key in "${!RESULTS[@]}"; do
        if [[ "${RESULTS[$key]}" == "failed" ]]; then
            has_failures=1
            break
        fi
    done

    if [[ "$has_failures" -eq 1 ]]; then
        printf "  ${C_YELLOW}Done with errors. Review warnings above.${C_RESET}\n"
        return 1
    else
        printf "  ${C_GREEN}${C_BOLD}Done!${C_RESET} Restart your shell to pick up changes.\n"
    fi
    printf '\n'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
