```
     _       _    __ _ _
  __| | ___ | |_ / _(_) | ___  ___
 / _` |/ _ \| __| |_| | |/ _ \/ __|
| (_| | (_) | |_|  _| | |  __/\__ \
 \__,_|\___/ \__|_| |_|_|\___||___/
```

My development environment, portable across WSL, Linux, and macOS. Spent way too long debugging shell PATH issues and broken toolchain managers before scrapping everything and starting fresh. This is the result.

Uses [GNU Stow](https://www.gnu.org/software/stow/) for symlink management -- each top-level directory is a stow package that mirrors `$HOME`.

## Quick Start

```bash
git clone git@github.com:randalmurphal/dotfiles.git ~/repos/dotfiles
cd ~/repos/dotfiles
bash install.sh        # interactive, defaults to yes
bash install.sh --all  # no prompts
```

## What's In Here

```
shell/       zsh config (modular: core, aliases, functions, path, toolchains)
git/         gitconfig with delta, aliases, global gitignore
tmux/        tmux.conf (Ctrl+Space prefix, dark purple theme, TPM)
wezterm/     wezterm.lua (dark purple theme, resurrect plugin, sysinfo status bar)
bin/         utility scripts: dotfiles, mkvenv, pbcopy, pbpaste, open
setup/       provisioning scripts (pyenv, nvm, go, rust, packages, wsl)
extras/      sysinfo-daemon (Rust), optional extras
docs/        cheat sheets (tmux, nvim, bash)
```

## Design Decisions

**No shims.** pyenv adds the Python version binary directory straight to PATH. No magic interceptors, no mysterious "command not found" from stale shims.

**Lazy-loaded nvm.** The default Node version's bin goes straight on PATH; `nvm.sh` itself (~2 seconds) loads only when you call `nvm`. No stubs for `node`/`npm`/`pnpm`: a stub can only shadow the real binary, and Claude Code's shell snapshot carried the stubs without `NVM_DIR`, which is exactly how it did.

**Agent shells get environment only.** Claude Code and Codex source `.zshrc` from a non-interactive login shell and snapshot the result into every command. `.zshrc` detects that (non-interactive, or the agents' env markers) and loads only `local.zsh`, `path.zsh` and `toolchains.zsh`: no oh-my-zsh, no prompt hooks, no zoxide, no aliases, plus `no_nomatch no_equals bsd_echo` so globs, `===` and `echo` behave like bash. Your interactive shell is untouched. `dotfiles doctor` checks it.

**Stow, not symlink scripts.** One command to link, one to unlink, conflict detection built in. No hand-rolled symlink management to debug at 2am.

**Machine-local overrides.** `~/.zsh/local.zsh` and `~/.gitconfig.local` for stuff that doesn't belong in a repo (work email, `DEFAULT_VENV` path, machine-specific aliases). Never tracked, never committed.

**Separate config repos for AI tools.** Claude Code and Codex configs live in their own repos ([claude-config](https://github.com/randalmurphal/claude-config), [codex-config](https://github.com/randalmurphal/codex-config)) -- the installer clones them into `~/.claude` and `~/.codex`.

## The Installer

Interactive by default. Each section shows `[Y/n]` and defaults to yes -- hit enter to accept, `n` to skip. Idempotent: run it again after adding local stuff and it won't clobber anything.

```bash
bash install.sh                    # interactive menu
bash install.sh --all              # everything, no prompts
bash install.sh --section shell    # just one section
bash install.sh --section shell --section git  # a few sections
```

Sections: `packages`, `shell`, `git`, `tmux`, `wezterm`, `python`, `node`, `go`, `rust`, `neovim`, `claude`, `codex`, `wsl`

## After Install

```bash
dotfiles doctor   # check symlinks, tools, versions
dotfiles update   # git pull + restow everything
dotfiles sync     # copy wezterm config to Windows side (WSL)
dotfiles edit     # open the repo in your editor
```

## Platform Support

| Platform | Package Manager | Status |
|----------|----------------|--------|
| Ubuntu/Debian (WSL2) | apt | daily driver |
| macOS (Apple Silicon) | Homebrew | tested |
| macOS (Intel) | Homebrew | tested |
| Fedora/RHEL | dnf | supported |
| Arch/Manjaro | pacman | supported |
| openSUSE | zypper | supported |

## Theme

Dark purple everywhere. Terminal, tmux, WezTerm, neovim -- all matching.

```
bg-dark:     #050505    bg-surface:  #121218    bg-elevated: #1a1a2e
purple:      #9d4edd    text:        #e0e0e0    dim:         #606060
```

## License

Do whatever you want with it. If it saves you from debugging PATH issues for three hours, it was worth publishing.
