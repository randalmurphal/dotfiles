# Bash Configuration
# Modular configs in ~/.bash/, machine-local overrides in ~/.bash/local.sh

# Environment first: every shell gets it, agent shells included. Claude Code
# and Codex source this file from a non-interactive login shell and snapshot
# the result into every command they run; Agent Overflow probes PATH with
# `bash -ilc`. Codex carries exports into its commands, Claude Code carries
# only PATH and functions (its settings.json "env" is where agent-only
# variables go).
[[ -f "$HOME/.bash/local.sh" ]]      && source "$HOME/.bash/local.sh"
[[ -f "$HOME/.bash/path.sh" ]]       && source "$HOME/.bash/path.sh"
[[ -f "$HOME/.bash/toolchains.sh" ]] && source "$HOME/.bash/toolchains.sh"

# Agent shells stop here. A command string (`bash -c`, `bash -ilc`) is never a
# terminal session even with -i, and the markers catch an agent that starts
# one interactively. Anything interactive below (ble.sh, prompt hooks,
# zoxide's cd hook, aliases) would otherwise leak into every agent command.
if [[ $- != *i* || -n "${BASH_EXECUTION_STRING-}" || -n "${CLAUDECODE-}" \
    || -n "${CODEX_MANAGED_BY_NPM-}${CODEX_MANAGED_BY_BUN-}${CODEX_MANAGED_BY_PNPM-}" ]]; then
    # /etc/profile.d and local.sh define aliases; agents get none
    unalias -a
    return
fi

[[ -f "$HOME/.bash/core.sh" ]]      && source "$HOME/.bash/core.sh"
[[ -f "$HOME/.bash/aliases.sh" ]]   && source "$HOME/.bash/aliases.sh"
[[ -f "$HOME/.bash/functions.sh" ]] && source "$HOME/.bash/functions.sh"

# ble.sh attaches last, after every hook and binding above is in place
[[ -z "${BLE_VERSION-}" ]] || ble-attach
