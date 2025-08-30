# Loaded for interactive shells
fpath=( "$HOME/.zsh/functions" $fpath )

# Speedup git tab completion - http://superuser.com/questions/458906/zsh-tab-completion-of-git-commands-is-very-slow-how-can-i-turn-it-off
__git_files () {
    _wanted files expl 'local files' _files
}

autoload -U compinit
zmodload -i zsh/complist
compinit

autoload -U promptinit
promptinit
#prompt clint
prompt myprompt1

zstyle ':vcs_info:*' enable git svn

setopt inc_append_history
# Don't record commands starting with a space
setopt hist_ignore_space
# Record timestamps
setopt extended_history

setopt hashcmds
setopt hashdirs

bindkey -e

# https://wiki.archlinux.org/index.php/zsh
# create a zkbd compatible hash;
# to add other keys to this hash, see: man 5 terminfo
typeset -A key
key[Home]=${terminfo[khome]}
key[End]=${terminfo[kend]}
key[Insert]=${terminfo[kich1]}
key[Delete]=${terminfo[kdch1]}
key[Up]=${terminfo[kcuu1]}
key[Down]=${terminfo[kcud1]}
key[Left]=${terminfo[kcub1]}
key[Right]=${terminfo[kcuf1]}
key[PageUp]=${terminfo[kpp]}
key[PageDown]=${terminfo[knp]}
# setup key accordingly
[[ -n "${key[Home]}"     ]]  && bindkey  "${key[Home]}"     beginning-of-line
[[ -n "${key[End]}"      ]]  && bindkey  "${key[End]}"      end-of-line
[[ -n "${key[Insert]}"   ]]  && bindkey  "${key[Insert]}"   overwrite-mode
[[ -n "${key[Delete]}"   ]]  && bindkey  "${key[Delete]}"   delete-char
[[ -n "${key[Up]}"       ]]  && bindkey  "${key[Up]}"       up-line-or-history
[[ -n "${key[Down]}"     ]]  && bindkey  "${key[Down]}"     down-line-or-history
[[ -n "${key[Left]}"     ]]  && bindkey  "${key[Left]}"     backward-char
[[ -n "${key[Right]}"    ]]  && bindkey  "${key[Right]}"    forward-char
[[ -n "${key[PageUp]}"   ]]  && bindkey  "${key[PageUp]}"   beginning-of-buffer-or-history
[[ -n "${key[PageDown]}" ]]  && bindkey  "${key[PageDown]}" end-of-buffer-or-history

bindkey '\e[H'    beginning-of-line
bindkey '\e[F'    end-of-line

# Don't ask to confirm rm -f!
setopt rmstarsilent
# Don't assume $arg should be "$arg"
# http://zsh.sourceforge.net/FAQ/zshfaq03.html
setopt shwordsplit
# Don't try to make /u/b/s into /usr/bin/sed, it's too slow for NFS.
zstyle ':completion:*' path-completion false
zstyle ':completion:*' accept-exact-dirs true
# Don't consider 'blah 2>&1 >/dev/null' to send both to 1. Work as it should.
setopt nomultios

export HISTFILE=~/.zhistory

if which direnv >/dev/null 2>&1; then
	eval "$(direnv hook zsh)"
fi

if [ -f "${HOME}/.rc.common" ]; then
	. "${HOME}/.rc.common"
fi
if [ -f ${HOME}/.zshrc.local ]; then
	. ${HOME}/.zshrc.local
fi
# vim: set filetype=zsh:
