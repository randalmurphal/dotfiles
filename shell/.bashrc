# Bash Configuration
#
# Bash is the login shell and the shell every agent runs (Claude Code, Codex,
# Agent Overflow). A terminal you type in hands off to zsh (~/.zshrc), which
# sources the same ~/.bash/*.sh files, so PATH, exports, aliases and functions
# are written once, here, in syntax both shells accept.
# Machine-local overrides: ~/.bash/local.sh.

# A terminal session is interactive, reads from a tty, is not running a
# command string (`bash -c`, Agent Overflow's `bash -ilc` probe) and was not
# started by an agent. Everything else is an agent shell. The tty test is
# zsh's own test for "interactive": without it a `bash -i` fed through a pipe
# would hand off to a zsh that reads no config at all.
__terminal=1
if [[ $- != *i* || ! -t 0 || -n "${BASH_EXECUTION_STRING-}" || -n "${CLAUDECODE-}" \
    || -n "${CODEX_MANAGED_BY_NPM-}${CODEX_MANAGED_BY_BUN-}${CODEX_MANAGED_BY_PNPM-}" ]]; then
    __terminal=""
fi

# Terminals run zsh: autosuggestions and syntax highlighting are native there
# (ble.sh did the same in bash at many times the cost per keystroke). $SHELL
# and the login shell stay bash, which is what the agents read, so one started
# from this terminal still runs bash. `DOTFILES_BASH=1 bash` keeps bash.
if [[ -n "$__terminal" && -z "${DOTFILES_BASH-}" ]]; then
    if command -v zsh >/dev/null 2>&1; then
        exec zsh
    fi
    echo "[WARN] zsh not found, staying in bash. Run 'bash install.sh --section packages' in dotfiles." >&2
fi

# Environment: every bash gets it, agent shells included. Claude Code and
# Codex source this file from a non-interactive login shell and snapshot the
# result into every command they run. Codex carries exports into its
# commands, Claude Code carries only PATH and functions (its settings.json
# "env" is where agent-only variables go).
[[ -f "$HOME/.bash/local.sh" ]]      && source "$HOME/.bash/local.sh"
[[ -f "$HOME/.bash/path.sh" ]]       && source "$HOME/.bash/path.sh"
[[ -f "$HOME/.bash/toolchains.sh" ]] && source "$HOME/.bash/toolchains.sh"

# Agent shells stop here, with no aliases (/etc/profile.d and local.sh define
# some) and nothing interactive.
if [[ -z "$__terminal" ]]; then
    unset __terminal
    unalias -a
    return
fi
unset __terminal

# A terminal that stayed in bash: system defaults (RHEL-family and macOS keep
# bash-completion behind /etc/bashrc for non-login shells), aliases, functions.
# The prompt, history search and plugins are zsh's and are not duplicated here.
[[ -f /etc/bashrc ]]                && source /etc/bashrc
[[ -f "$HOME/.bash/aliases.sh" ]]   && source "$HOME/.bash/aliases.sh"
[[ -f "$HOME/.bash/functions.sh" ]] && source "$HOME/.bash/functions.sh"

# Nothing below this line. An installer that appends here reaches neither
# zsh terminals nor agents; PATH and exports belong in ~/.bash/path.sh or
# ~/.bash/local.sh. `dotfiles doctor` checks this is the last line.
# end of .bashrc
