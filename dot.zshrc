# Unset TERMCAP from screen as it is wrong with 256colors and breaks vim
unset TERMCAP

fpath=( "$HOME/.zsh/functions" $fpath )

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

# Don't ask to confirm rm -f!
setopt rmstarsilent

. ${HOME}/.profile.common

export HISTFILE=~/.zhistory

[ -f ${HOME}/.zshrc.local ] && . ${HOME}/.zshrc.local
