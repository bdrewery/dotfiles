# Loaded for login shells
: ${PROFILE_REPO:=${HOME}/.profile-repo}

. ${HOME}/.profile.common
if [ -f ${HOME}/.zprofile.local ]; then
	. ${HOME}/.zprofile.local
fi
# vim: set filetype=zsh:
