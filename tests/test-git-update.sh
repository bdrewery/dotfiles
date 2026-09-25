#! /bin/sh
# Tests for git_update in libexec/install-lib.sh.
#
# A local bare repo stands in for GitHub.  Installed copies are shallow
# clones that must follow the remote's default branch when it is renamed
# (master -> main, with master retained), without manual steps.  A failed
# update must be reported rather than leaving the checkout silently stale.
#
# Usage: sh tests/test-git-update.sh
# Dependencies: git and POSIX utilities; no network access.

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
# Submodules here are local file:// repos, which git refuses by default.
# Upstream tracking must not depend on branch.autosetupmerge.
GIT_CONFIG_COUNT=2
GIT_CONFIG_KEY_0=protocol.file.allow
GIT_CONFIG_VALUE_0=always
GIT_CONFIG_KEY_1=branch.autosetupmerge
GIT_CONFIG_VALUE_1=false
export HOME GIT_CONFIG_GLOBAL GIT_CONFIG_NOSYSTEM GIT_AUTHOR_NAME \
    GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL \
    GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0 \
    GIT_CONFIG_KEY_1 GIT_CONFIG_VALUE_1

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

# rename_remote
# Rename master to main in REMOTE and make it the default, as GitHub does,
# then recreate master at the same commit, retained for old checkouts.
rename_remote() {
	git -C "${REMOTE:?}" branch -m master main &&
	    git -C "${REMOTE:?}" symbolic-ref HEAD refs/heads/main &&
	    git -C "${REMOTE:?}" branch master main
}

# setup_remote
# Create REMOTE with a default branch of master.
setup_remote() {
	rm -rf "${REMOTE:?}"
	git init --quiet --bare -b master "${REMOTE}" &&
	    commit_remote master c1
}

# assert_updated <dir> <message> <branch>
# Assert file "f" in <dir> contains <message>, local <branch> is checked
# out, is the only local branch and tracks origin/<branch>, and origin/HEAD
# points at origin/<branch>.
assert_updated() {
	local _dir="${1:?}" _msg="${2:?}" _branch="${3:?}" _head _local
	case "$(cat "${_dir}/f")" in
	"${_msg}") ;;
	*) fail "${_dir##*/}: content '$(cat "${_dir}/f")' != '${_msg}'" ;;
	esac
	_local="$(git -C "${_dir}" branch --show-current)"
	case "${_local}" in
	"${_branch}") ;;
	*) fail "${_dir##*/}: on branch '${_local}' != '${_branch}'" ;;
	esac
	_local="$(git -C "${_dir}" for-each-ref --format='%(refname)' \
	    refs/heads | tr '\n' ' ')"
	case "${_local}" in
	"refs/heads/${_branch} ") ;;
	*) fail "${_dir##*/}: local branches '${_local}' != '${_branch}'" ;;
	esac
	_local="$(git -C "${_dir}" for-each-ref --format='%(upstream)' \
	    "refs/heads/${_branch}")"
	case "${_local}" in
	"refs/remotes/origin/${_branch}") ;;
	*) fail "${_dir##*/}: upstream '${_local}' != origin/${_branch}" ;;
	esac
	_head="$(git -C "${_dir}" symbolic-ref --quiet refs/remotes/origin/HEAD)"
	case "${_head}" in
	"refs/remotes/origin/${_branch}") ;;
	*) fail "${_dir##*/}: origin/HEAD -> '${_head}' != origin/${_branch}" ;;
	esac
}

# run_update <dir>
# Run git_update on <dir>, recording a failure if it returns non-zero.
run_update() {
	git_update "${1##*/}" "${1:?}" >/dev/null 2>&1 ||
	    fail "${1##*/}: git_update returned $?"
}

# run_update_fails <dir>
# Run git_update on <dir>, recording a failure if it returns zero.
run_update_fails() {
	if git_update "${1##*/}" "${1:?}" >/dev/null 2>&1; then
		fail "${1##*/}: git_update returned 0"
	fi
}

test_no_rename() {
	local _d="${WORK:?}/norename"
	setup_remote || return 1
	git clone --quiet --depth=1 "${REMOTE_URL}" "${_d}" || return 1
	commit_remote master c2 || return 1
	run_update "${_d}"
	assert_updated "${_d}" c2 master
}

# A clone made with --depth=1 only fetches its original branch, master.
# The retained master must not be followed once main is the default.
test_rename_single_branch() {
	local _d="${WORK:?}/single"
	setup_remote || return 1
	git clone --quiet --depth=1 "${REMOTE_URL}" "${_d}" || return 1
	rename_remote || return 1
	commit_remote main c2 || return 1
	run_update "${_d}"
	assert_updated "${_d}" c2 main
	commit_remote main c3 || return 1
	run_update "${_d}"
	assert_updated "${_d}" c3 main
}

# A full clone fetches main, but its origin/HEAD still names master.
test_rename_full_clone() {
	local _d="${WORK:?}/full"
	setup_remote || return 1
	git clone --quiet "${REMOTE_URL}" "${_d}" || return 1
	rename_remote || return 1
	commit_remote main c2 || return 1
	run_update "${_d}"
	assert_updated "${_d}" c2 main
}

# git before 2.48 cannot update origin/HEAD during a fetch; the check must
# read the version from any vendor's "git version" string.
test_git_version_check() {
	local _case _ver _want _got
	for _case in "2.47.1:no" "2.48.0:yes" "2.55.0:yes" "3.0.0:yes" \
	    "1.99.9:no" "2.39.3 (Apple Git-146):no" "2.48.1.windows.1:yes" \
	    "garbage:no"; do
		_ver="${_case%:*}"
		_want="${_case##*:}"
		# shellcheck disable=SC2317 # invoked by git_follows_remote_head
		_got="$(git() { echo "git version ${_ver}"; }
		    if git_follows_remote_head; then echo yes; else echo no; fi)"
		case "${_got}" in
		"${_want}") ;;
		*) fail "version: '${_ver}' -> ${_got}, want ${_want}" ;;
		esac
	done
}

# git before 2.48 re-reads origin/HEAD with "remote set-head --auto".
test_rename_without_follow_remote_head() {
	local _d="${WORK:?}/oldgit" _before="${FAILURES}"
	setup_remote || return 1
	git clone --quiet --depth=1 "${REMOTE_URL}" "${_d}" || return 1
	rename_remote || return 1
	commit_remote main c2 || return 1
	(
		# shellcheck disable=SC2317 # invoked by git_update
		git_follows_remote_head() { return 1; }
		run_update "${_d}"
		[ "${FAILURES}" -eq "${_before}" ]
	) || FAILURES=$((FAILURES + 1))
	assert_updated "${_d}" c2 main
}

# A clone made after the rename starts out on main.
test_fresh_clone_after_rename() {
	local _d="${WORK:?}/fresh"
	setup_remote || return 1
	rename_remote || return 1
	git clone --quiet --depth=1 "${REMOTE_URL}" "${_d}" || return 1
	commit_remote main c2 || return 1
	run_update "${_d}"
	assert_updated "${_d}" c2 main
}

# Local refs named like the remote-tracking ones, or like options, must not
# change what is checked out or reported.
test_ambiguous_ref_name() {
	local _d="${WORK:?}/ambiguous" _out
	setup_remote || return 1
	rename_remote || return 1
	git clone --quiet --depth=1 "${REMOTE_URL}" "${_d}" || return 1
	git -C "${_d}" branch origin/main || return 1
	git -C "${_d}" branch origin/HEAD || return 1
	git -C "${_d}" update-ref refs/heads/-x HEAD || return 1
	commit_remote main c2 || return 1
	_out="$(git_update ambiguous "${_d}" 2>&1)" ||
	    fail "ambiguous: git_update returned $?"
	case "${_out}" in
	*"HEAD is now at "*" c2"*) ;;
	*) fail "ambiguous: no 'HEAD is now at ... c2' in output: ${_out}" ;;
	esac
	assert_updated "${_d}" c2 main
}

# The update reports the commit it landed on.
test_reports_head() {
	local _d="${WORK:?}/report" _out
	setup_remote || return 1
	git clone --quiet --depth=1 "${REMOTE_URL}" "${_d}" || return 1
	commit_remote master c2 || return 1
	_out="$(git_update report "${_d}" 2>&1)" ||
	    fail "report: git_update returned $?"
	case "${_out}" in
	*"HEAD is now at "*" c2"*) ;;
	*) fail "report: no 'HEAD is now at ... c2' in output: ${_out}" ;;
	esac
}

# Installed copies are not edited in place; updating discards local edits.
test_discards_local_changes() {
	local _d="${WORK:?}/dirty"
	setup_remote || return 1
	git clone --quiet --depth=1 "${REMOTE_URL}" "${_d}" || return 1
	commit_remote master c2 || return 1
	echo local-edit > "${_d}/f" || return 1
	run_update "${_d}"
	assert_updated "${_d}" c2 master
}

# Branches deleted on the remote must not linger as remote-tracking refs.
test_prunes_deleted_branches() {
	local _d="${WORK:?}/prune"
	setup_remote || return 1
	commit_remote feature f1 || return 1
	git clone --quiet --depth=1 "${REMOTE_URL}" "${_d}" || return 1
	run_update "${_d}"
	git -C "${_d}" rev-parse --quiet --verify \
	    refs/remotes/origin/feature >/dev/null ||
	    fail "prune: origin/feature was not fetched"
	git -C "${REMOTE}" branch -D feature >/dev/null || return 1
	run_update "${_d}"
	if git -C "${_d}" rev-parse --quiet --verify \
	    refs/remotes/origin/feature >/dev/null; then
		fail "prune: stale origin/feature remains"
	fi
	assert_updated "${_d}" c1 master
}

# assert_fetch_skipped <dir> <output>
# Assert a failed fetch was reported in <output> and <dir> still has c1.
assert_fetch_skipped() {
	case "${2}" in
	*"Fetch failed; keeping the current checkout"*) ;;
	*) fail "${1##*/}: fetch failure not reported: ${2}" ;;
	esac
	assert_updated "${1:?}" c1 master
}

# An offline host keeps its checkout: a failed fetch is shown, not fatal.
test_unreachable_remote() {
	local _d="${WORK:?}/unreachable" _out
	setup_remote || return 1
	git clone --quiet --depth=1 "${REMOTE_URL}" "${_d}" || return 1
	mv "${REMOTE}" "${REMOTE}.gone" || return 1
	_out="$(git_update unreachable "${_d}" 2>&1)" ||
	    fail "unreachable: git_update returned $?"
	mv "${REMOTE}.gone" "${REMOTE}" || return 1
	assert_fetch_skipped "${_d}" "${_out}"
}

# The remote is reachable but the fetch fails: its tip object is missing.
test_fetch_failure() {
	local _d="${WORK:?}/fetchfail" _obj _out
	setup_remote || return 1
	git clone --quiet --depth=1 "${REMOTE_URL}" "${_d}" || return 1
	commit_remote master c2 || return 1
	_obj="$(git -C "${REMOTE}" rev-parse master)" || return 1
	_obj="${REMOTE}/objects/$(printf '%s' "${_obj}" | cut -c1-2)/$(
	    printf '%s' "${_obj}" | cut -c3-)"
	rm "${_obj:?}" || return 1
	_out="$(git_update fetchfail "${_d}" 2>&1)" ||
	    fail "fetchfail: git_update returned $?"
	assert_fetch_skipped "${_d}" "${_out}"
}

# assert_exported_revision <label>
# Assert a child process, like the install.sh that update.sh execs, sees
# PROFILE_GIT_UPDATE_REVISION set to GIT_UPDATE_REVISION.
assert_exported_revision() {
	local _rev
	# shellcheck disable=SC2016 # expanded by the child shell
	_rev="$(sh -c 'printf %s "${PROFILE_GIT_UPDATE_REVISION:-unset}"')"
	case "${_rev}" in
	"${GIT_UPDATE_REVISION:?}") ;;
	*) fail "revision: child sees '${_rev}' ${1:?}" ;;
	esac
}

# install.sh re-runs git_update unless the revision that ran matches its
# own, so git_update must export its revision even when the fetch fails.
test_exports_revision() {
	local _d="${WORK:?}/revision"
	setup_remote || return 1
	git clone --quiet --depth=1 "${REMOTE_URL}" "${_d}" || return 1
	unset PROFILE_GIT_UPDATE_REVISION
	run_update "${_d}"
	assert_exported_revision "after update"
	unset PROFILE_GIT_UPDATE_REVISION
	mv "${REMOTE}" "${REMOTE}.gone" || return 1
	run_update "${_d}"
	mv "${REMOTE}.gone" "${REMOTE}" || return 1
	assert_exported_revision "after failed fetch"
}

# A detached HEAD is drift like any other: it ends up on the default branch.
test_detached_head() {
	local _d="${WORK:?}/detached"
	setup_remote || return 1
	git clone --quiet --depth=1 "${REMOTE_URL}" "${_d}" || return 1
	git -C "${_d}" checkout --quiet --detach || return 1
	commit_remote master c2 || return 1
	run_update "${_d}"
	assert_updated "${_d}" c2 master
}

# Any failure other than fetching is an error.  A held index lock makes the
# reset fail; the checkout must be left on a valid commit, not an unborn
# branch, and the next update recovers.
test_update_failure_is_error() {
	local _d="${WORK:?}/locked"
	setup_remote || return 1
	git clone --quiet --depth=1 "${REMOTE_URL}" "${_d}" || return 1
	rename_remote || return 1
	commit_remote main c2 || return 1
	: > "${_d}/.git/index.lock" || return 1
	run_update_fails "${_d}"
	rm -f "${_d:?}/.git/index.lock"
	git -C "${_d}" rev-parse --quiet --verify HEAD >/dev/null ||
	    fail "locked: HEAD does not resolve after a failed update"
	run_update "${_d}"
	assert_updated "${_d}" c2 main
}

# A submodule that cannot be fetched is reported like a failed fetch; the
# update itself still lands.
test_submodule_failure() {
	local _d="${WORK:?}/submodule" _sub="${WORK:?}/sub.git" _tmp _out
	_tmp="${WORK:?}/sub.tmp"
	setup_remote || return 1
	git init --quiet --bare -b master "${_sub}" || return 1
	rm -rf "${_tmp:?}"
	git init --quiet -b master "${_tmp}" || return 1
	git -C "${_tmp}" commit --quiet --allow-empty -m s1 || return 1
	git -C "${_tmp}" push --quiet "${_sub}" master || return 1
	rm -rf "${_tmp:?}"
	git clone --quiet "${REMOTE_URL}" "${_tmp}" || return 1
	git -C "${_tmp}" submodule --quiet add "file://${_sub}" sub || return 1
	echo c2 > "${_tmp}/f" || return 1
	git -C "${_tmp}" commit --quiet -am c2 || return 1
	git -C "${_tmp}" push --quiet "${REMOTE}" HEAD:master || return 1
	rm -rf "${_tmp:?}"
	git clone --quiet --depth=1 "${REMOTE_URL}" "${_d}" || return 1
	rm -rf "${_sub:?}"
	_out="$(git_update submodule "${_d}" 2>&1)" ||
	    fail "submodule: git_update returned $?"
	case "${_out}" in
	*"Submodule update failed"*) ;;
	*) fail "submodule: failure not reported: ${_out}" ;;
	esac
	assert_updated "${_d}" c2 master
}

for t in test_no_rename test_rename_single_branch test_rename_full_clone \
    test_git_version_check test_rename_without_follow_remote_head \
    test_fresh_clone_after_rename test_ambiguous_ref_name test_reports_head \
    test_discards_local_changes \
    test_prunes_deleted_branches \
    test_unreachable_remote test_fetch_failure test_exports_revision \
    test_detached_head \
    test_update_failure_is_error test_submodule_failure; do
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
