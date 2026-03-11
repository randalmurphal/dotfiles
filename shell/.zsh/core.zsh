# Core ZSH Configuration - oh-my-zsh, prompt, history, completions

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""

# Fix Homebrew completions on macOS
if [[ "$OSTYPE" == "darwin"* ]] && type brew &>/dev/null; then
    FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
    rm -f /usr/local/share/zsh/site-functions/_brew_cask 2>/dev/null
fi

# Dynamically load plugins based on what's available
plugins=()
[ -d "$ZSH/plugins/git" ] && plugins+=(git)
[ -d "$ZSH/plugins/python" ] && plugins+=(python)
[ -d "$ZSH/plugins/pip" ] && plugins+=(pip)
[ -d "$ZSH/plugins/docker" ] && plugins+=(docker)
[ -d "$ZSH/plugins/tmux" ] && plugins+=(tmux)
[ -d "$ZSH/plugins/fzf" ] && plugins+=(fzf)

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
    echo "[WARN] oh-my-zsh not found. Run 'dotfiles' installer to set up." >&2
fi

# Syntax highlighting from brew (must be after oh-my-zsh)
if [ "$ZSH_HIGHLIGHT_BREW" = true ]; then
    if [ -f "/opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
        source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
    elif [ -f "/usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
        source /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
    fi
fi

# FZF integration
[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ] && source /usr/share/doc/fzf/examples/key-bindings.zsh
[ -f /usr/share/doc/fzf/examples/completion.zsh ] && source /usr/share/doc/fzf/examples/completion.zsh
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Completion styling
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# History
HISTSIZE=50000
SAVEHIST=50000
HISTFILE=~/.zsh_history
setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS

# Autosuggestions config
bindkey '^E' autosuggest-accept
bindkey '^[[1;5C' forward-word
ZSH_AUTOSUGGEST_STRATEGY=(match_prev_cmd history)

# Terminal CWD reporting (OSC 7) for WezTerm
chpwd() { printf '\e]7;file://%s%s\e\\' "${HOST}" "${PWD}" }
chpwd

# Custom prompt
git_branch() {
  local branch=$(git symbolic-ref --short HEAD 2>/dev/null)
  if [[ -n "$branch" ]]; then
    echo "%F{244}$branch%f"
  fi
}

virtualenv_info() {
  if [[ -n "$VIRTUAL_ENV" ]]; then
    echo "%F{214}($(basename $VIRTUAL_ENV))%f"
  fi
}

setopt PROMPT_SUBST
export VIRTUAL_ENV_DISABLE_PROMPT=1
PROMPT='$(virtualenv_info)[%F{green}%n%f:%F{blue}%m%f]$(git_branch | sed "s/.*/:&/"):%F{magenta}%1~%f$ '

# Environment
export REPOS_PATH="${REPOS_PATH:-$HOME/repos}"
