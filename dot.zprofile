# Loaded for login shells
: ${PROFILE_REPO:=${HOME}/.profile-repo}

if which direnv >/dev/null 2>&1; then
	eval "$(direnv hook zsh)"
fi

. ${HOME}/.profile.common
if [ -f ${HOME}/.zprofile.local ]; then
	. ${HOME}/.zprofile.local
fi
# vim: set filetype=zsh:
