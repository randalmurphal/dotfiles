# dotfiles - Development Environment

Personal dotfiles managed with GNU Stow.

## Structure

```
dotfiles/
├── install.sh              # Interactive installer (bash install.sh / bash install.sh --all)
├── shell/                  # Stow package: .zshrc + .zsh/*.zsh
├── git/                    # Stow package: .gitconfig + .gitignore_global
├── tmux/                   # Stow package: .tmux.conf
├── wezterm/                # Stow package: .wezterm.lua
├── bin/                    # Stow package: .local/bin/ scripts
├── setup/                  # Provisioning scripts (not stowed)
│   ├── packages.sh         # System packages (apt/dnf/pacman/zypper/brew)
│   ├── python.sh           # pyenv + Python
│   ├── node.sh             # nvm + Node.js
│   ├── go.sh               # Go (direct download)
│   ├── rust.sh             # rustup
│   └── wsl.sh              # WSL-specific setup
├── extras/                 # Optional extras (not stowed)
│   └── sysinfo-daemon/     # Rust daemon for WezTerm status bar
├── docs/                   # Cheat sheets (referenced by tmux keybindings)
├── packages/               # Package lists (reference)
└── Brewfile                # macOS Homebrew bundle
```

## How Stow Works

Each top-level directory is a stow "package". Running `stow shell` from the repo creates symlinks in `$HOME` mirroring the package structure:

- `shell/.zshrc` -> `~/.zshrc`
- `shell/.zsh/core.zsh` -> `~/.zsh/core.zsh`
- `git/.gitconfig` -> `~/.gitconfig`
- `bin/.local/bin/dotfiles` -> `~/.local/bin/dotfiles`

## Machine-Local Overrides

These files are NOT tracked in git:
- `~/.zsh/local.zsh` - Machine-specific shell config (aliases, exports, DEFAULT_VENV)
- `~/.gitconfig.local` - Git identity (name, email), included by .gitconfig

## Key Patterns

- **No shims**: pyenv adds the version bin directly to PATH, not shims
- **Lazy-loaded nvm**: the default version's bin is on PATH directly; only `nvm()` is a stub. Never re-add node/npm/pnpm stubs: Claude Code's snapshot carries functions but not `NVM_DIR`, so a stub shadows a working binary with `. /nvm.sh`
- **Agent shells get environment only**: `.zshrc` sets `AGENT_SHELL` for a non-interactive shell or one carrying `CLAUDECODE` / `CODEX_MANAGED_BY_*`, loads only local/path/toolchains, sets `no_nomatch no_equals bsd_echo`, and unaliases everything. Anything interactive (oh-my-zsh, chpwd hooks, zoxide, completions) goes behind `[[ -z "$AGENT_SHELL" ]]`
- **PATH-based venv detection**: Checks `$PATH` not `$VIRTUAL_ENV` for activation guard
- **Cross-platform clipboard**: pbcopy/pbpaste/open wrappers handle WSL, Linux, macOS

## Editing

Always edit files in this repo, not the symlinked copies in `~`. After editing:
- Shell configs: `source ~/.zshrc` to reload
- WezTerm (WSL): Must copy to Windows side: `cp wezterm/.wezterm.lua /mnt/c/Users/$USER/.wezterm.lua`
- Tmux: `prefix + r` to reload

## Testing Changes

```bash
dotfiles doctor   # Check health of symlinks and tools
dotfiles update   # Pull latest + restow all packages
```
