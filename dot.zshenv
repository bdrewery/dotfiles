: ${PROFILE_REPO:=${HOME}/.profile-repo}

. "${HOME}/.env.common"
if which mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi
source_local "${HOME}/.zshenv"
# vim: set filetype=zsh:
