# PATH additions - portable across machines
# Order: last added = first in PATH (prepending)

# Prepend a directory that exists and is not already on PATH. Agents source
# .bashrc more than once per shell (Codex: login, then again for its
# snapshot), so a plain prepend would double every entry.
path_prepend() {
    [[ -d "$1" ]] || return 0
    case ":$PATH:" in
        *":$1:"*) ;;
        *) PATH="$1:$PATH" ;;
    esac
}

# WSL appends every directory on the Windows PATH (two dozen under /mnt/c).
# Each is a round trip to Windows, so a lookup of a command that exists
# nowhere walked them all: ~70 ms a miss, in terminals and agent shells
# alike. Keep the ones something here calls (cmd.exe, clip.exe, explorer.exe,
# wsl.exe, powershell.exe) and the editor launchers (code, cursor, zed); any
# other Windows program runs through `powershell.exe -c` or its full path.
# Windows paths are case-insensitive (C:\WINDOWS on some installs), so each
# entry is matched in lowercase; `typeset -l` lowercases on assignment in
# bash and zsh alike. Parameter expansion only: no fork in either shell.
if [[ "$PATH" == */mnt/[a-z]/* && -r /proc/sys/kernel/osrelease \
    && "$(</proc/sys/kernel/osrelease)" == *[Mm]icrosoft* ]]; then
    typeset -l __lower
    __rest="$PATH:" __kept=""
    while [[ -n "$__rest" ]]; do
        __entry="${__rest%%:*}"
        __rest="${__rest#*:}"
        __lower="${__entry%/}"
        case "$__lower" in
            /mnt/[a-z]/windows | /mnt/[a-z]/windows/system32) ;;
            /mnt/[a-z]/windows/system32/windowspowershell/*) ;;
            /mnt/[a-z]/*/microsoft\ vs\ code/bin) ;;
            /mnt/[a-z]/*/cursor/resources/app/bin) ;;
            /mnt/[a-z]/*/zed/bin) ;;
            /mnt/[a-z]/*) continue ;;
        esac
        __kept="${__kept:+$__kept:}$__entry"
    done
    PATH="$__kept"
    unset __rest __entry __kept __lower
fi

# Lowest priority
path_prepend /snap/bin

# Homebrew: Intel, then ARM
path_prepend /usr/local/bin
path_prepend /opt/homebrew/bin

# User toolchains
path_prepend "$HOME/.cargo/bin"

# User local bins - highest priority
path_prepend "$HOME/.local/bin"

export PATH
