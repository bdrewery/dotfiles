: ${PROFILE_REPO:=${HOME}/.profile-repo}

# .env.common is included in .zprofile to avoid macOS /etc/zprofile path_helper
# moving /usr/local/bin to the front. For non-login this is not a problem.

case $- in
# login shell handled in dot.zprofile
*l*) ;;
*)
	. "${HOME}/.env.common"
	;;
esac
. "${PROFILE_REPO}/libexec/local.sh"
source_local "${HOME}/.zshenv"
# vim: set filetype=zsh:
