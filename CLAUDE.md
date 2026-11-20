# dotfiles - Development Environment

Personal dotfiles managed with GNU Stow.

## Structure

```
dotfiles/
├── install.sh              # Interactive installer (bash install.sh / bash install.sh --all)
├── shell/                  # Stow package: .bashrc (agents; hands terminals to zsh), .zshrc (terminals), .bash/*.sh (shared by both), .bash_profile, .inputrc
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
- `shell/.bash/path.sh` -> `~/.bash/path.sh`
- `git/.gitconfig` -> `~/.gitconfig`
- `bin/.local/bin/dotfiles` -> `~/.local/bin/dotfiles`

## Machine-Local Overrides

These files are NOT tracked in git:
- `~/.bash/local.sh` - Machine-specific shell config (aliases, exports, DEFAULT_VENV, CA bundle); loads first in bash and in zsh, agent shells included
- `~/.gitconfig.local` - Git identity (name, email), included by .gitconfig

## Key Patterns

- **No shims**: uv installs Python; venvs and any leftover pyenv version bin go on PATH directly, never shims
- **Lazy-loaded nvm**: the default version's bin is on PATH directly; only `nvm()` is a stub. Never re-add node/npm/pnpm stubs: Claude Code's snapshot carries functions but not `NVM_DIR`, so a stub shadows a working binary with `. /nvm.sh`
- **Bash for agents, zsh for terminals**: bash is the login shell and `$SHELL`, which is where agents get their shell (Codex from the account database, Claude Code and Agent Overflow from `$SHELL`), so `chsh` stays bash. `.bashrc` execs zsh for a terminal only: `$-` has `i`, stdin is a tty, `BASH_EXECUTION_STRING` is empty (Agent Overflow probes with `bash -ilc`) and no `CLAUDECODE` / `CODEX_MANAGED_BY_*` marker is set. `DOTFILES_BASH=1 bash` keeps bash. `.zshrc` applies the same test, so on a machine whose login shell is still zsh an agent gets environment only there too
- **Agent shells get environment only**: every other bash loads local/path/toolchains and returns with `unalias -a`. Claude Code's snapshot keeps functions but takes PATH from its launching process and drops other exports, so a variable Claude needs goes in its `settings.json` env; Codex carries exports. PATH entries go through `path_prepend` (agents source `.bashrc` twice)
- **One config, two shells**: `.zshrc` sources the same `~/.bash/*.sh` files, so write them for both shells: no `shopt`, `complete` or `declare -n`, quote every expansion (zsh does not word-split an unquoted `$var`), and avoid numeric array indexes (zsh starts at 1). `dotfiles doctor` starts zsh and fails on a startup error, which catches syntax but not a difference in meaning. PATH and exports go in `path.sh` or `local.sh`: a line appended to `.bashrc` sits after the handoff and never runs, and one in `.zshrc` never reaches an agent. Only the line editor, prompt, history and plugins are zsh-specific, in `.zshrc`
- **Windows PATH trimmed on WSL**: `path.sh` keeps only System32, Windows, WindowsPowerShell and the VS Code / Cursor / Zed launcher folders out of the two dozen `/mnt/c` directories WSL appends (a failed command lookup walked them all, ~70 ms). Any other Windows program (`scoop`, `pwsh.exe`, `node.exe`) runs through `powershell.exe -c` or its full path; to keep another folder, add its lowercase pattern to the `case` in `path.sh` (a `/mnt/<drive>` entry added in `local.sh` is trimmed too, since `local.sh` loads first)
- **PATH-based venv detection**: Checks `$PATH` not `$VIRTUAL_ENV` for activation guard
- **Cross-platform clipboard**: pbcopy/pbpaste/open wrappers handle WSL, Linux, macOS

## Editing

Always edit files in this repo, not the symlinked copies in `~`. After editing:
- Shell configs: open a new terminal
- WezTerm (WSL): Must copy to Windows side with `dotfiles sync`, which also sets the default distro to the one it runs from (a plain `cp` leaves the repo's fallback name)
- Tmux: `prefix + r` to reload

## Testing Changes

```bash
dotfiles doctor   # Check health of symlinks and tools
dotfiles update   # Pull latest + restow all packages
dotfiles upgrade  # Reinstall tool categories at their latest release (no args: list)
```
