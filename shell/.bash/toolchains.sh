# Language Toolchains - nvm, Go, Bun, Python venvs (Rust is on PATH via path.sh)

# ========================================
# NVM (Node Version Manager) - LAZY LOADED
# ========================================
# nvm.sh costs ~2s, so only `nvm` itself loads it, on first call. node, npm,
# pnpm and friends need no stub: the default version's bin goes on PATH
# below, and a stub would only shadow it. (Claude Code's snapshot carries
# functions but not NVM_DIR, so the stub defaults it rather than trusting
# the export to have travelled with it.)
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    nvm() {
        unset -f nvm
        \. "${NVM_DIR:-$HOME/.nvm}/nvm.sh"
        [[ -s "${NVM_DIR:-$HOME/.nvm}/bash_completion" ]] && \. "${NVM_DIR:-$HOME/.nvm}/bash_completion"
        nvm "$@"
    }

    if [[ -d "$NVM_DIR/versions/node" ]]; then
        _nvm_default=$(head -1 "$NVM_DIR/alias/default" 2>/dev/null)
        if [[ -n "$_nvm_default" ]]; then
            if [[ -d "$NVM_DIR/versions/node/$_nvm_default" ]]; then
                _nvm_version="$_nvm_default"
            else
                _nvm_version=$(command ls -1 "$NVM_DIR/versions/node" 2>/dev/null | command grep "^v${_nvm_default}" | tail -1)
            fi
            if [[ -n "$_nvm_version" ]]; then
                path_prepend "$NVM_DIR/versions/node/$_nvm_version/bin"
            fi
            unset _nvm_version
        fi
        unset _nvm_default
    fi
fi

# ========================================
# Go
# ========================================
path_prepend /usr/local/go/bin

export GOPATH="${GOPATH:-$HOME/go}"
path_prepend "$GOPATH/bin"

# ========================================
# Bun
# ========================================
export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
path_prepend "$BUN_INSTALL/bin"

export PATH

# ========================================
# Python Virtual Environments
# ========================================
DEFAULT_VENV="${DEFAULT_VENV:-}"

# Helper to switch venvs
venv() {
    local venv_path="${1:-$DEFAULT_VENV}"

    if [[ -z "$venv_path" ]]; then
        echo "Usage: venv <path_or_name>"
        echo "Set DEFAULT_VENV in ~/.bash/local.sh for a default"
        return 1
    fi

    # If just a name, look in common locations
    if [[ ! "$venv_path" == /* ]] && [[ ! "$venv_path" == ./* ]]; then
        if [[ -d "/opt/envs/$venv_path" ]]; then
            venv_path="/opt/envs/$venv_path"
        elif [[ -d "$HOME/.venvs/$venv_path" ]]; then
            venv_path="$HOME/.venvs/$venv_path"
        elif [[ -d "./$venv_path" ]]; then
            venv_path="./$venv_path"
        fi
    fi

    if [[ -f "$venv_path/bin/activate" ]]; then
        source "$venv_path/bin/activate"
        echo "Activated: $venv_path (Python $(python --version 2>&1 | cut -d' ' -f2))"
    else
        echo "No venv found at: $venv_path"
        return 1
    fi
}
