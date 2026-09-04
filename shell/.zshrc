# ZSH Configuration
# Modular configs in ~/.zsh/, machine-local overrides in ~/.zsh/local.zsh

ZSHRC_DIR="$HOME/.zsh"
export REPOS_PATH="${REPOS_PATH:-$HOME/repos}"

# Agent shells get environment only. Claude Code and Codex source this file
# from a NON-interactive login shell and snapshot the result (functions,
# options, exports) into every command they run, so anything interactive
# here leaks into the agent: oh-my-zsh's hundreds of functions, the OSC 7
# chpwd hook (which prefixed every tool output with an escape sequence),
# zoxide's chpwd hook (which would rank agent cd's in the z database), and
# every alias. Codex sets no agent marker on a native install, so the
# interactive test is the primary gate and the markers are belt and braces.
AGENT_SHELL=""
if [[ ! -o interactive || -n "$CLAUDECODE" || -n "$CODEX_MANAGED_BY_NPM$CODEX_MANAGED_BY_BUN$CODEX_MANAGED_BY_PNPM" ]]; then
    AGENT_SHELL=1
fi

# Machine-local config first (sets machine-specific vars like WSL_DISTRO
# that other modules depend on)
[[ -f "$ZSHRC_DIR/local.zsh" ]]       && source "$ZSHRC_DIR/local.zsh"

if [[ -z "$AGENT_SHELL" ]]; then
    [[ -f "$ZSHRC_DIR/core.zsh" ]]        && source "$ZSHRC_DIR/core.zsh"
    [[ -f "$ZSHRC_DIR/aliases.zsh" ]]     && source "$ZSHRC_DIR/aliases.zsh"
    [[ -f "$ZSHRC_DIR/functions.zsh" ]]   && source "$ZSHRC_DIR/functions.zsh"
fi
[[ -f "$ZSHRC_DIR/path.zsh" ]]        && source "$ZSHRC_DIR/path.zsh"
[[ -f "$ZSHRC_DIR/toolchains.zsh" ]]  && source "$ZSHRC_DIR/toolchains.zsh"

if [[ -n "$AGENT_SHELL" ]]; then
    # The three zsh defaults agents trip on, set to what bash does: an
    # unmatched glob passes through literally instead of aborting the
    # command, a word starting with = is not a command lookup (=== as a
    # separator), and echo prints backslashes instead of interpreting them.
    # Both agents capture setopts into their snapshot, so these hold for
    # every command; an interactive shell never reaches this branch.
    setopt no_nomatch no_equals bsd_echo
    unalias -a
    return
fi

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
