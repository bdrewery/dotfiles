: ${PROFILE_REPO:=${HOME}/.profile-repo}

. ${HOME}/.env.common
if [ -f ${HOME}/.zshenv.local ]; then
	. ${HOME}/.zshenv.local
fi
