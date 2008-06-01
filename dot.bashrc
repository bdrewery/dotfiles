# .bashrc
# $Id$

# User specific aliases and functions

# Source global definitions
if [ -f /etc/bashrc ]; then
        . /etc/bashrc
fi

alias monitor_server3='tail -n 400 -F /usr/local/aolserver/log/server.log | grep -v nsopenssl'
alias grep='grep --color=auto'

export PS1="[\u@\h \W]\j|$(echo \$?)\$ "
export EDITOR=vim
