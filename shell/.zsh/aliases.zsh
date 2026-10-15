# Aliases - portable across machines

# Editor
if command -v nvim &> /dev/null; then
    alias vim='nvim'
    alias vi='nvim'
    alias v='nvim'
fi

# Git shortcuts
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --all'
alias gd='git diff'

# Agent CLIs
alias c='claude --dangerously-skip-permissions'
alias cc='claude --dangerously-skip-permissions'
alias cx='codex --yolo'

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias cdd="cd $REPOS_PATH/dotfiles"
alias cdnv="cd ~/.config/nvim"

# OS-specific
if [[ "$OSTYPE" == "darwin"* ]]; then
    alias ls='ls -laG'
    alias ll='ls -laG'
    alias la='ls -laG'
    if command -v bat &> /dev/null; then
        alias cat='bat'
    fi
    if command -v gdu &> /dev/null; then
        alias du='gdu'
        alias ncdu='gdu'
    elif command -v ncdu &> /dev/null; then
        alias du='ncdu'
    fi
else
    alias ls='ls -la --color=auto'
    alias ll='ls -la --color=auto'
    alias la='ls -la --color=auto'
    if command -v batcat &> /dev/null; then
        alias cat='batcat'
        alias bat='batcat'
    elif command -v bat &> /dev/null; then
        alias cat='bat'
    fi
    if command -v gdu &> /dev/null; then
        alias du='gdu'
        alias ncdu='gdu'
    elif command -v ncdu &> /dev/null; then
        alias du='ncdu'
    fi
fi

# Long running command notification
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'
