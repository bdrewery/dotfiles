if [ -f ~/.bashrc ]; then
  . ~/.bashrc
fi
: ${PROFILE_REPO:=${HOME}/.profile-repo}

. ${HOME}/.profile.common

if [ -f ~/.bash_profile.local ]; then
  . ~/.bash_profile.local
fi
