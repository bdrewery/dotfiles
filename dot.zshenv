: ${PROFILE_REPO:=${HOME}/.profile-repo}

if [ -r "${HOME}/.env.common" ]; then
	. ${HOME}/.env.common
fi
if [ -r ${HOME}/.zshenv.local ]; then
	. ${HOME}/.zshenv.local
fi
