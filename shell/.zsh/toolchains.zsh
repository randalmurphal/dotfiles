# Language Toolchains - pyenv, nvm, Go, Rust, Python venvs

# ========================================
# Pyenv (Python version manager)
# ========================================
# Adds pyenv-managed Python to PATH directly. No shims, no shell hooks.
if [[ -d "$HOME/.pyenv" ]]; then
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    _pyenv_version="$(cat "$PYENV_ROOT/version" 2>/dev/null | head -1)"
    if [[ -n "$_pyenv_version" && "$_pyenv_version" != "system" && -d "$PYENV_ROOT/versions/$_pyenv_version/bin" ]]; then
        export PATH="$PYENV_ROOT/versions/$_pyenv_version/bin:$PATH"
    fi
    unset _pyenv_version
fi

# ========================================
# NVM (Node Version Manager) - LAZY LOADED
# ========================================
export NVM_DIR="$HOME/.nvm"

if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    nvm() {
        unset -f nvm node npm npx yarn pnpm 2>/dev/null
        \. "$NVM_DIR/nvm.sh"
        [[ -s "$NVM_DIR/bash_completion" ]] && \. "$NVM_DIR/bash_completion"
        nvm "$@"
    }
    node() {
        unset -f nvm node npm npx yarn pnpm 2>/dev/null
        \. "$NVM_DIR/nvm.sh"
        command node "$@"
    }
    npm() {
        unset -f nvm node npm npx yarn pnpm 2>/dev/null
        \. "$NVM_DIR/nvm.sh"
        command npm "$@"
    }
    npx() {
        unset -f nvm node npm npx yarn pnpm 2>/dev/null
        \. "$NVM_DIR/nvm.sh"
        command npx "$@"
    }
    yarn() {
        unset -f nvm node npm npx yarn pnpm 2>/dev/null
        \. "$NVM_DIR/nvm.sh"
        command yarn "$@"
    }
    pnpm() {
        unset -f nvm node npm npx yarn pnpm 2>/dev/null
        \. "$NVM_DIR/nvm.sh"
        command pnpm "$@"
    }

    if [[ -d "$NVM_DIR/versions/node" ]]; then
        _nvm_default=$(cat "$NVM_DIR/alias/default" 2>/dev/null | head -1)
        if [[ -n "$_nvm_default" ]]; then
            if [[ -d "$NVM_DIR/versions/node/$_nvm_default" ]]; then
                _nvm_version="$_nvm_default"
            else
                _nvm_version=$(command ls -1 "$NVM_DIR/versions/node" 2>/dev/null | grep "^v${_nvm_default}" | tail -1)
            fi
            if [[ -n "$_nvm_version" && -d "$NVM_DIR/versions/node/$_nvm_version/bin" ]]; then
                export PATH="$NVM_DIR/versions/node/$_nvm_version/bin:$PATH"
            fi
            unset _nvm_version
        fi
        unset _nvm_default
    fi
fi

# ========================================
# Go
# ========================================
[ -d "$HOME/go-install/go/bin" ] && export PATH="$HOME/go-install/go/bin:$PATH"
[ -d "/usr/local/go/bin" ] && export PATH="/usr/local/go/bin:$PATH"

export GOPATH="${GOPATH:-$HOME/go}"
[ -d "$GOPATH/bin" ] && export PATH="$GOPATH/bin:$PATH"

# ========================================
# Rust (Cargo)
# ========================================
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"

# ========================================
# Python Virtual Environments
# ========================================
DEFAULT_VENV="${DEFAULT_VENV:-}"

# Helper to switch venvs
venv() {
    local venv_path="${1:-$DEFAULT_VENV}"

    if [[ -z "$venv_path" ]]; then
        echo "Usage: venv <path_or_name>"
        echo "Set DEFAULT_VENV in ~/.zsh/local.zsh for a default"
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
