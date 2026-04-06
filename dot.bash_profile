# Loaded for login shells
if [ -f ~/.bashrc ]; then
  . ~/.bashrc
fi
: "${PROFILE_REPO:=${HOME}/.profile-repo}"

. "${HOME}/.profile.common"
source_local "${HOME}/.bash_profile"
# vim: set filetype=bash:
