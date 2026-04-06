# Loaded for login shells
: "${PROFILE_REPO:=${HOME}/.profile-repo}"

# See dot.zshenv comment.
case $- in
*l*)
	. "${HOME}/.env.common"
	;;
esac

. "${HOME}/.profile.common"
source_local "${HOME}/.zprofile"
# vim: set filetype=zsh:
