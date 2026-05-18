#! /bin/sh
: "${PROFILE_REPO:=$(realpath "$(dirname "$0")")}"
. "${PROFILE_REPO:?}/libexec/install-lib.sh"

update() {
	local repo_name=".profile-repo"
	local repo_dir="${PROFILE_REPO:?}"

	git_update "${repo_name:?}" "${repo_dir:?}"
	cd "${repo_dir:?}"
	echo "==> ${repo_name:?}: Installing"
	exec ./install.sh
}
update
