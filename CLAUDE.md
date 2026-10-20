# dotfiles - Development Environment

Personal dotfiles managed with GNU Stow.

## Structure

```
dotfiles/
├── install.sh              # Interactive installer (bash install.sh / bash install.sh --all)
├── shell/                  # Stow package: .bashrc, .bash_profile, .inputrc, .bash/*.sh (old .zshrc + .zsh/ unmaintained)
├── git/                    # Stow package: .gitconfig + .gitignore_global
├── tmux/                   # Stow package: .tmux.conf
├── wezterm/                # Stow package: .wezterm.lua
├── bin/                    # Stow package: .local/bin/ scripts
├── setup/                  # Provisioning scripts (not stowed)
│   ├── packages.sh         # System packages (apt/dnf/pacman/zypper/brew)
│   ├── user-tools.sh       # Linux: CLI tools (shell, k8s, docs, DB clients) from their releases; skips any already on PATH (macOS: Brewfile)
│   ├── audit-git-state.sh  # One-line-per-repo inventory of branch, head, upstream, dirty state
│   ├── python.sh           # uv + a uv-managed Python
│   ├── node.sh             # nvm + Node.js
│   ├── go.sh               # Go (direct download) + dlv, golangci-lint, govulncheck
│   ├── rust.sh             # rustup
│   └── wsl.sh              # WSL-specific setup
├── extras/                 # Optional extras (not stowed)
│   └── sysinfo-daemon/     # Rust daemon for WezTerm status bar
├── docs/                   # Cheat sheets (referenced by tmux keybindings)
└── Brewfile                # macOS Homebrew bundle
```

## How Stow Works

Each top-level directory is a stow "package". Running `stow shell` from the repo creates symlinks in `$HOME` mirroring the package structure:

- `shell/.bashrc` -> `~/.bashrc`
- `shell/.bash/core.sh` -> `~/.bash/core.sh`
- `git/.gitconfig` -> `~/.gitconfig`
- `bin/.local/bin/dotfiles` -> `~/.local/bin/dotfiles`

## Machine-Local Overrides

These files are NOT tracked in git:
- `~/.bash/local.sh` - Machine-specific shell config (aliases, exports, DEFAULT_VENV, CA bundle); loads first, agent shells included
- `~/.gitconfig.local` - Git identity (name, email), included by .gitconfig

## Key Patterns

- **No shims**: uv installs Python; venvs and any leftover pyenv version bin go on PATH directly, never shims
- **Lazy-loaded nvm**: the default version's bin is on PATH directly; only `nvm()` is a stub. Never re-add node/npm/pnpm stubs: Claude Code's snapshot carries functions but not `NVM_DIR`, so a stub shadows a working binary with `. /nvm.sh`
- **Agent shells get environment only**: `.bashrc` loads local/path/toolchains, then returns with `unalias -a` unless `$-` has `i`, `BASH_EXECUTION_STRING` is empty (Agent Overflow probes with `bash -ilc`) and no `CLAUDECODE` / `CODEX_MANAGED_BY_*` marker is set. Anything interactive (ble.sh, PROMPT_COMMAND hooks, zoxide, completions, aliases) goes in `core.sh`/`aliases.sh`, after that return. Claude Code's snapshot keeps functions but takes PATH from its launching process and drops other exports, so a variable Claude needs goes in its `settings.json` env; Codex carries exports. PATH entries go through `path_prepend` (agents source `.bashrc` twice)
- **Bash is the login shell**: Codex reads the shell from the account database and has no setting, so `chsh` is what makes it run bash
- **PATH-based venv detection**: Checks `$PATH` not `$VIRTUAL_ENV` for activation guard
- **Cross-platform clipboard**: pbcopy/pbpaste/open wrappers handle WSL, Linux, macOS

## Editing

Always edit files in this repo, not the symlinked copies in `~`. After editing:
- Shell configs: open a new terminal (ble.sh does not reload cleanly in place)
- WezTerm (WSL): Must copy to Windows side with `dotfiles sync`, which also sets the default distro to the one it runs from (a plain `cp` leaves the repo's fallback name)
- Tmux: `prefix + r` to reload

## Testing Changes

```bash
dotfiles doctor   # Check health of symlinks and tools
dotfiles update   # Pull latest + restow all packages
dotfiles upgrade  # Reinstall tool categories at their latest release (no args: list)
```
