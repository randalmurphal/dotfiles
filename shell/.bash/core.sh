# Core Bash Configuration - line editor, history, prompt, completions
# Interactive terminals only: .bashrc returns before this for agent shells.

# ble.sh (autosuggestions, syntax highlighting, completion menu). Loaded
# detached first so fzf and zoxide below hook into it; .bashrc attaches it
# last. Ctrl-E or Right accepts a suggestion. Key bindings come from ~/.inputrc.
BLESH="$HOME/.local/share/blesh/ble.sh"
if [[ -f "$BLESH" ]]; then
    source -- "$BLESH" --attach=none

    # Alt-Backspace deletes the previous word, as in zsh (ble.sh copies it)
    blehook/eval-after-load keymap_emacs '
        ble-bind -f M-DEL kill-backward-cword
        ble-bind -f M-C-? kill-backward-cword
        ble-bind -f M-BS kill-backward-cword
        ble-bind -f M-C-h kill-backward-cword'

    # Colors as zsh-syntax-highlighting and zsh-autosuggestions had them:
    # commands green, keywords and quotes yellow, an unknown command plain
    # red (ble.sh paints builtins red and errors white on red), suggestions gray
    ble-face command_builtin=fg=green command_builtin_dot=fg=green command_alias=fg=green
    ble-face command_function=fg=green command_file=fg=green command_jobs=fg=green
    ble-face command_keyword=fg=yellow syntax_quoted=fg=yellow syntax_quotation=fg=yellow
    ble-face syntax_error=fg=red,bold argument_error=fg=red filename_warning=none
    ble-face auto_complete=fg=242
else
    echo "[WARN] ble.sh not found. Run 'bash install.sh --section shell' in dotfiles." >&2
fi
unset BLESH

# System defaults. RHEL-family and macOS keep bash-completion and
# /etc/profile.d behind /etc/bashrc for non-login shells; Debian's
# /etc/bash.bashrc is read by bash itself.
[[ -f /etc/bashrc ]] && source /etc/bashrc

# Homebrew bash-completion on macOS
if [[ "$OSTYPE" == "darwin"* ]] && [[ -r /opt/homebrew/etc/profile.d/bash_completion.sh ]]; then
    source /opt/homebrew/etc/profile.d/bash_completion.sh
fi

# macOS starts shells at 256 open files; raise the soft limit to the
# per-process ceiling. Linux defaults are already far higher.
if [[ "$OSTYPE" == "darwin"* ]]; then
    ulimit -n "$(sysctl -n kern.maxfilesperproc)"
fi

# History: written as each command runs, duplicates dropped, timestamped
HISTSIZE=50000
HISTFILESIZE=50000
HISTCONTROL=ignoreboth:erasedups
HISTTIMEFORMAT='%F %T '
shopt -s histappend

# Before each prompt: flush history, report the CWD to WezTerm (OSC 7), and
# fill the prompt's git branch and venv. The prompt reads these as variables
# so a branch name is never expanded as code.
__prompt_command() {
    history -a
    printf '\e]7;file://%s%s\e\\' "$HOSTNAME" "$PWD"
    __ps1_branch=$(git symbolic-ref --short HEAD 2>/dev/null)
    __ps1_venv=${VIRTUAL_ENV:+${VIRTUAL_ENV##*/}}
}
PROMPT_COMMAND="__prompt_command${PROMPT_COMMAND:+;$PROMPT_COMMAND}"

# Custom prompt: (venv)[user:host]:branch:dir$
export VIRTUAL_ENV_DISABLE_PROMPT=1
PS1='${__ps1_venv:+\[\e[38;5;214m\](${__ps1_venv})\[\e[0m\]}[\[\e[32m\]\u\[\e[0m\]:\[\e[34m\]\h\[\e[0m\]]${__ps1_branch:+:\[\e[38;5;244m\]${__ps1_branch}\[\e[0m\]}:\[\e[35m\]\W\[\e[0m\]\$ '

# FZF integration (Ctrl-R history, Ctrl-T files, Alt-C cd)
load_fzf_integration() {
    local fzf_init="" fzf_base=""
    if command -v fzf >/dev/null 2>&1; then
        fzf_init="$(fzf --bash 2>/dev/null)" || true
        if [[ -n "$fzf_init" ]]; then
            eval "$fzf_init"
            return
        fi
    fi
    # fzf older than 0.48 has no --bash; use the scripts its package ships
    for fzf_base in \
        /usr/share/doc/fzf/examples \
        /usr/share/fzf/shell \
        /opt/homebrew/opt/fzf/shell \
        /usr/local/opt/fzf/shell \
        "$HOME/.fzf/shell"
    do
        if [[ -f "$fzf_base/key-bindings.bash" ]]; then
            source "$fzf_base/key-bindings.bash"
            [[ -f "$fzf_base/completion.bash" ]] && source "$fzf_base/completion.bash"
            return
        fi
    done
}
load_fzf_integration
unset -f load_fzf_integration

# Zoxide (smarter cd). Interactive only: its prompt hook records every cd,
# and an agent shell's cd's are not places you want ranked.
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init bash)"
fi
