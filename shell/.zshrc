# Zsh Configuration - the shell a terminal runs
#
# Bash is the login shell and the only shell agents see. ~/.bashrc hands an
# interactive terminal off to zsh, and everything past the environment below
# is for terminals only, so nothing here reaches an agent.
#
# PATH, exports, aliases and functions live in ~/.bash/*.sh, written in syntax
# both shells accept, and are sourced here unchanged (`dotfiles doctor` loads
# them in zsh). Only the line editor, prompt, history and completion below are
# zsh's own. Machine-local overrides: ~/.bash/local.sh.

# Environment: the same three files, in the same order, as ~/.bashrc
[[ -f "$HOME/.bash/local.sh" ]]      && source "$HOME/.bash/local.sh"
[[ -f "$HOME/.bash/path.sh" ]]       && source "$HOME/.bash/path.sh"
[[ -f "$HOME/.bash/toolchains.sh" ]] && source "$HOME/.bash/toolchains.sh"

# Everything below is for a terminal, by the same test .bashrc uses. Agents
# are meant to run bash, but on a machine whose login shell is still zsh they
# reach this file: sourced by hand from a non-interactive shell, or through
# `zsh -ilc` (Agent Overflow's probe). They get what .bashrc gives an agent,
# the environment and no aliases, plus the three zsh defaults agents trip on
# set to what bash does: an unmatched glob passes through, a word starting
# with = is not a command lookup, echo prints backslashes.
if [[ ! -o interactive || ! -t 0 || -n "${ZSH_EXECUTION_STRING-}" || -n "${CLAUDECODE-}" \
    || -n "${CODEX_MANAGED_BY_NPM-}${CODEX_MANAGED_BY_BUN-}${CODEX_MANAGED_BY_PNPM-}" ]]; then
    setopt no_nomatch no_equals bsd_echo
    unalias -m '*'
    return 0
fi

# ========================================
# oh-my-zsh and plugins
# ========================================
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""
# No update check at startup: once one is due, oh-my-zsh calls the GitHub API
# from every new terminal (2 s timeout) and holds the prompt at a "[Y/n]"
# question, eating whatever was typed ahead. `dotfiles upgrade zsh` updates
# oh-my-zsh and both plugins.
zstyle ':omz:update' mode disabled

# Fix Homebrew completions on macOS
if [[ "$OSTYPE" == "darwin"* ]] && type brew &>/dev/null; then
    FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
    rm -f /usr/local/share/zsh/site-functions/_brew_cask 2>/dev/null
fi

# macOS starts shells at 256 open files; raise the soft limit to the
# per-process ceiling. Linux defaults are already far higher.
if [[ "$OSTYPE" == "darwin"* ]]; then
    ulimit -n "$(sysctl -n kern.maxfilesperproc)"
fi

# Dynamically load plugins based on what's available
plugins=()
[ -d "$ZSH/plugins/git" ] && plugins+=(git)
[ -d "$ZSH/plugins/python" ] && plugins+=(python)
[ -d "$ZSH/plugins/pip" ] && plugins+=(pip)
[ -d "$ZSH/plugins/docker" ] && plugins+=(docker)
[ -d "$ZSH/plugins/tmux" ] && plugins+=(tmux)

# Custom plugins
if [ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] || [ -d "$ZSH/custom/plugins/zsh-autosuggestions" ]; then
    plugins+=(zsh-autosuggestions)
elif [ -f "/opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
    source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
elif [ -f "/usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
    source /usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

if [ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] || [ -d "$ZSH/custom/plugins/zsh-syntax-highlighting" ]; then
    plugins+=(zsh-syntax-highlighting)
elif [ -f "/opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
    ZSH_HIGHLIGHT_BREW=true
elif [ -f "/usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
    ZSH_HIGHLIGHT_BREW=true
fi

if [[ -f "$ZSH/oh-my-zsh.sh" ]]; then
    source "$ZSH/oh-my-zsh.sh"
else
    echo "[WARN] oh-my-zsh not found. Run 'bash install.sh --section shell' in dotfiles." >&2
fi

# Syntax highlighting from brew (must be after oh-my-zsh)
if [ "$ZSH_HIGHLIGHT_BREW" = true ]; then
    if [ -f "/opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
        source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
    elif [ -f "/usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
        source /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
    fi
fi

# Aliases and functions, after oh-my-zsh so these win over its plugins' aliases
[[ -f "$HOME/.bash/aliases.sh" ]]   && source "$HOME/.bash/aliases.sh"
[[ -f "$HOME/.bash/functions.sh" ]] && source "$HOME/.bash/functions.sh"

# ========================================
# FZF integration (Ctrl-R history, Ctrl-T files, Alt-C cd)
# ========================================
load_fzf_integration() {
    local fzf_init=""
    local fzf_base=""
    local completion_file=""
    local key_bindings_file=""

    if command -v fzf >/dev/null 2>&1; then
        fzf_init="$(fzf --zsh 2>/dev/null)" || true
        if [[ -n "$fzf_init" ]]; then
            eval "$fzf_init"
            return
        fi
    fi

    # fzf older than 0.48 has no --zsh; use the scripts its package ships
    for fzf_base in \
        /usr/share/doc/fzf/examples \
        /usr/share/fzf/shell \
        /opt/homebrew/opt/fzf/shell \
        /usr/local/opt/fzf/shell \
        "$HOME/.fzf/shell"
    do
        if [[ -f "$fzf_base/completion.zsh" ]] && [[ -f "$fzf_base/key-bindings.zsh" ]]; then
            completion_file="$fzf_base/completion.zsh"
            key_bindings_file="$fzf_base/key-bindings.zsh"
            break
        fi
    done

    [[ -n "$completion_file" ]] && source "$completion_file" 2>/dev/null
    [[ -n "$key_bindings_file" ]] && source "$key_bindings_file" 2>/dev/null
    [[ -f "$HOME/.fzf.zsh" ]] && source "$HOME/.fzf.zsh" 2>/dev/null
}

load_fzf_integration
unset -f load_fzf_integration

# ========================================
# Completion, history, key bindings
# ========================================
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

HISTSIZE=50000
SAVEHIST=50000
HISTFILE=~/.zsh_history
setopt SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS

# Autosuggestions: Ctrl-E accepts
bindkey '^E' autosuggest-accept
bindkey '^[[1;5C' forward-word
# (match_prev_cmd needs history kept in order, which HIST_IGNORE_ALL_DUPS breaks)
ZSH_AUTOSUGGEST_STRATEGY=(history)

# ========================================
# Prompt: (venv)[user:host]:branch:dir$
# ========================================
# A precmd hook fills the branch and venv as variables, so each prompt costs
# one git call and a branch name is never expanded as code or as a prompt
# escape.
__prompt_precmd() {
    local branch
    branch=$(git symbolic-ref --short HEAD 2>/dev/null)
    __ps1_branch="" __ps1_venv=""
    [[ -n "$branch" ]] && __ps1_branch=":%F{244}${branch//\%/%%}%f"
    [[ -n "$VIRTUAL_ENV" ]] && __ps1_venv="%F{214}(${${VIRTUAL_ENV:t}//\%/%%})%f"
    return 0
}

# (WezTerm learns the directory from OSC 7, which oh-my-zsh's termsupport
# already sends before each prompt.)
autoload -Uz add-zsh-hook
add-zsh-hook precmd __prompt_precmd

setopt PROMPT_SUBST
export VIRTUAL_ENV_DISABLE_PROMPT=1
PROMPT='${__ps1_venv}[%F{green}%n%f:%F{blue}%m%f]${__ps1_branch}:%F{magenta}%1~%f$ '

# ========================================
# Zoxide (smarter cd) and bun completions
# ========================================
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init zsh)"
fi

[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# Nothing below this line. An installer that appends here reaches terminals
# only; PATH and exports belong in ~/.bash/path.sh or ~/.bash/local.sh, where
# agents get them too. `dotfiles doctor` checks this is the last line.
# end of .zshrc
