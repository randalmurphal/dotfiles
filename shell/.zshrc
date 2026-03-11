# ZSH Configuration
# Modular configs in ~/.zsh/, machine-local overrides in ~/.zsh/local.zsh

ZSHRC_DIR="$HOME/.zsh"

# Machine-local config first (sets DEFAULT_VENV, WSL_DISTRO, etc.
# that other modules depend on)
[[ -f "$ZSHRC_DIR/local.zsh" ]]       && source "$ZSHRC_DIR/local.zsh"

[[ -f "$ZSHRC_DIR/core.zsh" ]]        && source "$ZSHRC_DIR/core.zsh"
[[ -f "$ZSHRC_DIR/aliases.zsh" ]]     && source "$ZSHRC_DIR/aliases.zsh"
[[ -f "$ZSHRC_DIR/functions.zsh" ]]   && source "$ZSHRC_DIR/functions.zsh"
[[ -f "$ZSHRC_DIR/path.zsh" ]]        && source "$ZSHRC_DIR/path.zsh"
[[ -f "$ZSHRC_DIR/toolchains.zsh" ]]  && source "$ZSHRC_DIR/toolchains.zsh"
