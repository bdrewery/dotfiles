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

. ~/.profile.common

if [ -d ~/bin ] ; then
    PATH=~/bin:"${PATH}"
    export PATH
fi
if [ -d ~/man ]; then
    MANPATH=~/man:"${MANPATH}"
    export MANPATH
fi

# . ~/.profile-repo/git-prompt/git-prompt.sh

[[ -f "/etc/bash_completion.d/git" ]] &&
     . /etc/bash_completion.d/git

[[ -f "/usr/share/bash-completion/git" ]] &&
     . /usr/share/bash-completion/git

if [ -f ~/.bashrc.local ]; then
	. ~/.bashrc.local
fi
