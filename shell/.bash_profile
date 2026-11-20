# Login shells read this file instead of .bashrc; everything lives there.
[[ -f "$HOME/.bashrc" ]] && source "$HOME/.bashrc"

# Nothing below this line: after the line above, a terminal is already zsh.
# PATH and exports belong in ~/.bash/path.sh or ~/.bash/local.sh.
# end of .bash_profile
