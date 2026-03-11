# PATH additions - portable across machines
# Order: last added = first in PATH (prepending)

# Lowest priority
[ -d "/snap/bin" ] && export PATH="/snap/bin:$PATH"

# Homebrew: Intel, then ARM
[ -d "/usr/local/bin" ] && export PATH="/usr/local/bin:$PATH"
[ -d "/opt/homebrew/bin" ] && export PATH="/opt/homebrew/bin:$PATH"

# User toolchains
[ -d "$HOME/.cargo/bin" ] && export PATH="$HOME/.cargo/bin:$PATH"

# User local bins - highest priority
[ -d "$HOME/.local/bin" ] && export PATH="$HOME/.local/bin:$PATH"

# Zoxide (smarter cd)
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init zsh)"
fi
