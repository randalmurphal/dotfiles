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
