# Loaded for login shells
if [ -f ~/.bashrc ]; then
  . ~/.bashrc
fi
: ${PROFILE_REPO:=${HOME}/.profile-repo}

if which direnv >/dev/null 2>&1; then
	eval "$(direnv hook bash)"
fi

. ${HOME}/.profile.common
source_local "${HOME}/.bash_profile"
# vim: set filetype=bash:
