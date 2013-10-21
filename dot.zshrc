autoload -U compinit
zmodload -i zsh/complist
compinit

autoload -U promptinit
promptinit
prompt clint

zstyle ':vcs_info:*' enable git svn

setopt inc_append_history
# Don't record commands starting with a space
setopt hist_ignore_space
# Record timestamps
setopt extended_history

setopt hashcmds
setopt hashdirs

bindkey -e
bindkey "^[[1~" beginning-of-line
bindkey "^[[4~" end-of-line
bindkey "^[[3~" delete-char
bindkey "^[[2~" overwrite-mode

# Don't ask to confirm rm -f!
setopt rmstarsilent

. ${HOME}/.profile.common

export HISTFILE=~/.zhistory

[ -f ${HOME}/.zshrc.local ] && . ${HOME}/.zshrc.local
