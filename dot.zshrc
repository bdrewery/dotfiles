autoload -U compinit
compinit

autoload -U promptinit
promptinit
prompt clint

setopt inc_append_history
# Don't record commands starting with a space
setopt hist_ignore_space

#bindkey    "^[[3~"          delete-char
#bindkey    "^[3;5~"         delete-char

bindkey "^[[1~" beginning-of-line
bindkey "^[[4~" end-of-line
bindkey "^[[3~" delete-char
bindkey "^[[2~" overwrite-mode

. ${HOME}/.profile.common

export HISTFILE=~/.zhistory

[ -f ${HOME}/.zshrc.local ] && . ${HOME}/.zshrc.local
