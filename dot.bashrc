# .bashrc
# $Id$

# User specific aliases and functions

# Test for an interactive shell.  There is no need to set anything
# past this point for scp and rcp, and it's important to refrain from
# outputting anything in those cases.
if [[ $- != *i* ]] ; then
        # Shell is non-interactive.  Be done now!
        return
fi


# Source global definitions
if [ -f /etc/bashrc ]; then
        . /etc/bashrc
fi

if [ -f ~/.bash_completion ]; then
		. ~/.bash_completion
fi

alias monitor_server='tail -n 400 -F /usr/local/aolserver/log/server.log | grep -v nsopenssl'
alias grep='grep --color=auto'

which setterm > /dev/null 2>&1 && setterm -blength 0

#export PS1="[\u@\h \W]\j|$(echo \$?)\$ "
export EDITOR=vim


if [ -d ~/bin ] ; then
    PATH=~/bin:"${PATH}"
    export PATH
fi
if [ -d ~/man ]; then
    MANPATH=~/man:"${MANPATH}"
    export MANPATH
fi

export LESS="R E F"
export HISTSIZE=10000000000000 2>/dev/null
export IGNOREEOF=1
export HISTFILESIZE=10000000000000 2>/dev/null

# Disable XOFF (^S)
stty -ixon

. ~/.profile-repo/git-prompt/git-prompt.sh
