#! /bin/sh
# Tests for git_update in libexec/install-lib.sh.
#
# A local bare repo stands in for GitHub.  Installed copies are shallow
# clones, so the remote's default branch being renamed (master -> main) must
# be followed without manual steps, and a failed fetch must be reported
# rather than leaving the checkout silently stale.
#
# Usage: sh tests/test-git-update.sh
# Dependencies: git, sed; no network access.

TESTS_DIR="$(cd "$(dirname "$0")" && pwd -P)" || exit 1
# shellcheck source=libexec/install-lib.sh
. "${TESTS_DIR:?}/../libexec/install-lib.sh" || exit 1

WORK="$(mktemp -d "${TMPDIR:-/tmp}/test-git-update.XXXXXX")" || exit 1
trap 'rm -rf "${WORK:?}"' EXIT
trap 'exit 1' INT TERM HUP

# Keep the user's git config and identity out of the test.
HOME="${WORK:?}"
GIT_CONFIG_GLOBAL=/dev/null
GIT_CONFIG_NOSYSTEM=1
GIT_AUTHOR_NAME="test"
GIT_AUTHOR_EMAIL=test@example.com
GIT_COMMITTER_NAME="test"
GIT_COMMITTER_EMAIL=test@example.com
export HOME GIT_CONFIG_GLOBAL GIT_CONFIG_NOSYSTEM GIT_AUTHOR_NAME \
    GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL

REMOTE="${WORK:?}/remote.git"
# file:// so --depth is honored for local clones.
REMOTE_URL="file://${REMOTE:?}"
FAILURES=0

# fail <message>
# Record a failed assertion.
fail() {
	echo "FAIL: $*" >&2
	FAILURES=$((FAILURES + 1))
}

# commit_remote <branch> <message>
# Add a commit with file "f" containing <message> to <branch> of REMOTE.
commit_remote() {
	local _branch="${1:?}" _msg="${2:?}" _tmp
	_tmp="${WORK:?}/commit.tmp"
	rm -rf "${_tmp:?}"
	if git -C "${REMOTE:?}" rev-parse --quiet --verify \
	    "refs/heads/${_branch}" >/dev/null; then
		git clone --quiet --branch "${_branch}" "${REMOTE_URL}" \
		    "${_tmp}" || return 1
	else
		git init --quiet -b "${_branch}" "${_tmp}" || return 1
	fi
	printf '%s\n' "${_msg}" > "${_tmp}/f" || return 1
	git -C "${_tmp}" add f || return 1
	git -C "${_tmp}" commit --quiet -m "${_msg}" || return 1
	git -C "${_tmp}" push --quiet "${REMOTE}" \
	    "HEAD:refs/heads/${_branch}" || return 1
	rm -rf "${_tmp:?}"
}

# rename_remote_branch <old> <new>
# Rename <old> to <new> in REMOTE and make it the default, as GitHub does.
rename_remote_branch() {
	git -C "${REMOTE:?}" branch -m "${1:?}" "${2:?}" &&
	    git -C "${REMOTE:?}" symbolic-ref HEAD "refs/heads/${2:?}"
}

# setup_remote
# Create REMOTE with a default branch of master.
setup_remote() {
	rm -rf "${REMOTE:?}"
	git init --quiet --bare -b master "${REMOTE}" &&
	    commit_remote master c1
}

# assert_updated <dir> <branch> <message>
# Assert <dir> is on local <branch> at the remote commit <message>, with
# origin/HEAD pointing at origin/<branch> and no refs left for other branches.
assert_updated() {
	local _dir="${1:?}" _branch="${2:?}" _msg="${3:?}" _refs
	case "$(cat "${_dir}/f")" in
	"${_msg}") ;;
	*) fail "${_dir##*/}: content '$(cat "${_dir}/f")' != '${_msg}'" ;;
	esac
	case "$(git -C "${_dir}" branch --show-current)" in
	"${_branch}") ;;
	*) fail "${_dir##*/}: on branch" \
	    "'$(git -C "${_dir}" branch --show-current)' != '${_branch}'" ;;
	esac
	case "$(git -C "${_dir}" symbolic-ref --quiet refs/remotes/origin/HEAD)" in
	"refs/remotes/origin/${_branch}") ;;
	*) fail "${_dir##*/}: origin/HEAD ->" \
	    "'$(git -C "${_dir}" symbolic-ref --quiet refs/remotes/origin/HEAD)'" ;;
	esac
	_refs="$(git -C "${_dir}" for-each-ref --format='%(refname)' \
	    refs/heads refs/remotes | tr '\n' ' ')"
	case "${_refs}" in
	"refs/heads/${_branch} refs/remotes/origin/HEAD refs/remotes/origin/${_branch} ") ;;
	*) fail "${_dir##*/}: unexpected refs: ${_refs}" ;;
	esac
}

# run_update <dir>
# Run git_update on <dir>, recording a failure if it returns non-zero.
run_update() {
	git_update "${1##*/}" "${1:?}" >/dev/null 2>&1 ||
	    fail "${1##*/}: git_update returned $?"
}

test_no_rename() {
	local _d="${WORK:?}/norename"
	setup_remote || return 1
	git clone --quiet --depth=1 "${REMOTE_URL}" "${_d}" || return 1
	commit_remote master c2 || return 1
	run_update "${_d}"
	assert_updated "${_d}" master c2
}

# A clone made with --depth=1 only fetches its original branch.
test_rename_single_branch() {
	local _d="${WORK:?}/single"
	setup_remote || return 1
	git clone --quiet --depth=1 "${REMOTE_URL}" "${_d}" || return 1
	rename_remote_branch master main || return 1
	commit_remote main c2 || return 1
	run_update "${_d}"
	assert_updated "${_d}" main c2
	commit_remote main c3 || return 1
	run_update "${_d}"
	assert_updated "${_d}" main c3
}

# A full clone fetches main, but its origin/HEAD still names master.
test_rename_full_clone() {
	local _d="${WORK:?}/full"
	setup_remote || return 1
	git clone --quiet "${REMOTE_URL}" "${_d}" || return 1
	rename_remote_branch master main || return 1
	commit_remote main c2 || return 1
	run_update "${_d}"
	assert_updated "${_d}" main c2
}

test_fresh_clone_after_rename() {
	local _d="${WORK:?}/fresh"
	setup_remote || return 1
	rename_remote_branch master main || return 1
	git clone --quiet --depth=1 "${REMOTE_URL}" "${_d}" || return 1
	commit_remote main c2 || return 1
	run_update "${_d}"
	assert_updated "${_d}" main c2
}

# Installed copies are not edited in place; updating discards local edits.
test_discards_local_changes() {
	local _d="${WORK:?}/dirty"
	setup_remote || return 1
	git clone --quiet --depth=1 "${REMOTE_URL}" "${_d}" || return 1
	commit_remote master c2 || return 1
	echo local-edit > "${_d}/f" || return 1
	run_update "${_d}"
	assert_updated "${_d}" master c2
}

test_unreachable_remote() {
	local _d="${WORK:?}/unreachable" _before
	setup_remote || return 1
	git clone --quiet --depth=1 "${REMOTE_URL}" "${_d}" || return 1
	_before="$(git -C "${_d}" rev-parse HEAD)" || return 1
	mv "${REMOTE}" "${REMOTE}.gone" || return 1
	if git_update unreachable "${_d}" >/dev/null 2>&1; then
		fail "unreachable: git_update returned 0"
	fi
	mv "${REMOTE}.gone" "${REMOTE}" || return 1
	case "$(git -C "${_d}" rev-parse HEAD)" in
	"${_before}") ;;
	*) fail "unreachable: HEAD moved" ;;
	esac
	assert_updated "${_d}" master c1
}

# ls-remote succeeds but the fetch does not: the remote's tip object is
# missing.  Nothing in the clone may change, including its fetch refspec.
test_fetch_failure() {
	local _d="${WORK:?}/fetchfail" _obj _refspec
	setup_remote || return 1
	git clone --quiet "${REMOTE_URL}" "${_d}" || return 1
	_refspec="$(git -C "${_d}" config --get-all remote.origin.fetch)" ||
	    return 1
	rename_remote_branch master main || return 1
	commit_remote main c2 || return 1
	_obj="$(git -C "${REMOTE}" rev-parse main)" || return 1
	_obj="${REMOTE}/objects/$(printf '%s' "${_obj}" | cut -c1-2)/$(printf '%s' "${_obj}" | cut -c3-)"
	rm "${_obj:?}" || return 1
	if git_update fetchfail "${_d}" >/dev/null 2>&1; then
		fail "fetchfail: git_update returned 0"
	fi
	case "$(cat "${_d}/f")" in
	c1) ;;
	*) fail "fetchfail: content changed to '$(cat "${_d}/f")'" ;;
	esac
	case "$(git -C "${_d}" branch --show-current)" in
	master) ;;
	*) fail "fetchfail: branch changed" ;;
	esac
	case "$(git -C "${_d}" config --get-all remote.origin.fetch)" in
	"${_refspec}") ;;
	*) fail "fetchfail: refspec changed to" \
	    "'$(git -C "${_d}" config --get-all remote.origin.fetch)'" ;;
	esac
}

for t in test_no_rename test_rename_single_branch test_rename_full_clone \
    test_fresh_clone_after_rename test_discards_local_changes \
    test_unreachable_remote test_fetch_failure; do
	_failures_before="${FAILURES}"
	if ! "${t}"; then
		fail "${t}: setup failed"
	fi
	case "${FAILURES}" in
	"${_failures_before}") echo "ok ${t}" ;;
	*) echo "not ok ${t}" ;;
	esac
done

case "${FAILURES}" in
0) echo "All tests passed" ;;
*) echo "${FAILURES} failure(s)" >&2; exit 1 ;;
esac
