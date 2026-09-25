#! /bin/sh
# End-to-end test of update-profile (update.sh -> git_update -> install.sh)
# across the master -> main rename.
#
# The real update.sh and install.sh run against a stand-in remote inside
# bwrap: the real filesystem is mounted read-only apart from the scratch
# directory, and there is no network.  Host sockets (e.g. under /run) and
# processes are not isolated; nothing the installer runs uses them.
# env -i keeps the caller's environment out; in particular an inherited
# PROFILE_REPO would otherwise point update.sh at the real ~/.profile-repo.
# PATH entries under $HOME are dropped so no personal script can shadow a
# tool.  Offline, submodule clones and pip installs fail; both are reported
# and the install goes on, as on an offline host.
#
# The code under test is this checkout's HEAD plus any uncommitted changes
# to tracked files, committed in a scratch clone as the remote's main, with
# one more commit that changes dot.login_conf.  install.sh copies that file
# rather than linking it, so its installed content shows that main's tip's
# install.sh ran.
#
# Scenarios, each a single update.sh run:
#   old          installed at OLD_REV, before git_update followed the default
#                branch; the remote's master is frozen at FROZEN_REV, as on
#                GitHub.  Must end on main's tip.
#   workstation  on main at FROZEN_REV with the leftover local master that
#                revision 1 of git_update kept.  Must end on main's tip.
#   current      already at main's tip.  Must fetch .profile-repo only once.
#
# Usage: sh tests/test-update-e2e.sh
# To test another git, put it first in PATH; it must not live under $HOME,
# since the sandbox PATH drops those entries.
# Dependencies: bwrap (skipped without it), git, and whatever install.sh
# runs (python3, zsh, rsync).  Slow: each scenario runs a full install.

# Last master before git_update followed the default branch.
OLD_REV=70d3c12cebfe5b8c3dee24cbfba72bcfd1b5f08f
# Where the frozen master on GitHub points: the PR #6 merge, which added the
# install.sh revision check with GIT_UPDATE_REVISION=1.  The workstation
# scenario relies on it being revision 1.
FROZEN_REV=bba301dc17df056b470e18d764f23e973c0783a1

TESTS_DIR="$(cd "$(dirname "$0")" && pwd -P)" || exit 1
REPO_ROOT="$(cd "${TESTS_DIR:?}/.." && pwd -P)" || exit 1

# Keep the caller's git environment out, such as GIT_DIR from a hook, so
# git commands act only on the repos named here.
# shellcheck disable=SC2046 # one variable name per word
unset $(git rev-parse --local-env-vars) GIT_TEMPLATE_DIR

if ! command -v bwrap >/dev/null 2>&1; then
	echo "skip: bwrap is not installed"
	exit 0
fi
if ! bwrap --ro-bind / / --unshare-net --dev /dev --proc /proc true; then
	echo "FAIL: bwrap is installed but cannot create a sandbox" >&2
	exit 1
fi
for _rev in "${OLD_REV}" "${FROZEN_REV}"; do
	if ! git -C "${REPO_ROOT}" cat-file -e "${_rev}^{commit}" 2>/dev/null
	then
		echo "FAIL: ${_rev} not in ${REPO_ROOT}; needs full history" >&2
		exit 1
	fi
done

WORK="$(mktemp -d "${TMPDIR:-/tmp}/test-update-e2e.XXXXXX")" || exit 1
trap 'rm -rf "${WORK:?}"' EXIT
trap 'exit 1' INT TERM HUP

# The caller's PATH without entries under $HOME.
SANDBOX_PATH="$(printf '%s\n' "${PATH}" | tr ':' '\n' |
    grep -v -e "^${HOME}/" -e "^${HOME}\$" | paste -s -d: -)"

# Scratch git operations outside the sandbox use no user config.
GIT_CONFIG_GLOBAL=/dev/null
GIT_CONFIG_NOSYSTEM=1
GIT_AUTHOR_NAME="test"
GIT_AUTHOR_EMAIL=test@example.com
GIT_COMMITTER_NAME="test"
GIT_COMMITTER_EMAIL=test@example.com
export GIT_CONFIG_GLOBAL GIT_CONFIG_NOSYSTEM GIT_AUTHOR_NAME \
    GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL

MARKER="# test-update-e2e marker $$"
FAILURES=0

# fail <message>
# Record a failed assertion.
fail() {
	echo "FAIL: $*" >&2
	FAILURES=$((FAILURES + 1))
}

# build_tip
# Commit this checkout's HEAD plus uncommitted changes, then a marker commit,
# in ${WORK}/src.  Sets TIP.
build_tip() {
	git clone --quiet --no-checkout "${REPO_ROOT}" "${WORK}/src" || return
	git -C "${WORK}/src" checkout --quiet --detach \
	    "$(git -C "${REPO_ROOT}" rev-parse HEAD)" || return
	git -C "${REPO_ROOT}" diff --binary HEAD |
	    git -C "${WORK}/src" apply --index --allow-empty || return
	git -C "${WORK}/src" commit --quiet --allow-empty -am \
	    "test: code under test" || return
	printf '%s\n' "${MARKER}" >> "${WORK}/src/dot.login_conf" || return
	git -C "${WORK}/src" commit --quiet -am "test: main tip" || return
	TIP="$(git -C "${WORK}/src" rev-parse HEAD)"
}

# sandbox <dir> <command> [args]
# Run <command> in bwrap with HOME=<dir>/home, only <dir> writable, no
# network and a clean environment.
sandbox() {
	local _s="${1:?}"
	shift
	bwrap --ro-bind / / --tmpfs /tmp --bind "${_s}" "${_s}" \
	    --dev /dev --proc /proc --unshare-net --die-with-parent \
	    /usr/bin/env -i HOME="${_s}/home" PATH="${SANDBOX_PATH}" \
	    TMPDIR="${_s}/tmp" TERM=dumb LANG=C.UTF-8 "$@" </dev/null
}

# new_scenario <name>
# Create ${WORK}/<name> with an empty home and bare remote.  Sets S.
new_scenario() {
	S="${WORK:?}/${1:?}"
	mkdir -p "${S}/home" "${S}/tmp" &&
	    git init --quiet --bare -b master "${S}/remote.git"
}

# remote_set <ref:branch>... [HEAD=<branch>]
# Point branches of ${S}/remote.git at commits from ${WORK}/src.
remote_set() {
	local _arg
	for _arg in "$@"; do
		case "${_arg}" in
		HEAD=*)
			git -C "${S}/remote.git" symbolic-ref HEAD \
			    "refs/heads/${_arg#HEAD=}" || return
			;;
		*)
			git -C "${WORK}/src" push --quiet --force \
			    "${S}/remote.git" \
			    "${_arg%%:*}:refs/heads/${_arg#*:}" || return
			;;
		esac
	done
}

# install_clone
# Install ${S}/home/.profile-repo as a shallow single-branch clone of the
# remote's current default branch, as hosts were set up.
install_clone() {
	git clone --quiet --depth=1 "file://${S}/remote.git" \
	    "${S}/home/.profile-repo"
}

# run_update_sh
# Run the installed update.sh once in the sandbox, logging to ${S}/log.
run_update_sh() {
	sandbox "${S}" sh "${S}/home/.profile-repo/update.sh" > "${S}/log" 2>&1
}

# assert_on_tip <name> <update.sh exit status>
# Assert the last update.sh run succeeded and left .profile-repo on main at
# TIP, main as the only local branch tracking origin/main, and the marker
# installed.
assert_on_tip() {
	local _name="${1:?}" _rc="${2:?}" _repo="${S}/home/.profile-repo" _v
	case "${_rc}" in
	0) ;;
	*) fail "${_name}: update.sh exited ${_rc}" ;;
	esac
	_v="$(git -C "${_repo}" rev-parse HEAD)"
	case "${_v}" in
	"${TIP}") ;;
	*) fail "${_name}: HEAD ${_v} != main tip ${TIP}" ;;
	esac
	_v="$(git -C "${_repo}" for-each-ref \
	    --format='%(refname)->%(upstream)' refs/heads | tr '\n' ' ')"
	case "${_v}" in
	"refs/heads/main->refs/remotes/origin/main ") ;;
	*) fail "${_name}: local branches: ${_v}" ;;
	esac
	_v="$(git -C "${_repo}" symbolic-ref --short HEAD)"
	case "${_v}" in
	main) ;;
	*) fail "${_name}: on branch ${_v}" ;;
	esac
	grep -qxF "${MARKER}" "${S}/home/.login_conf" ||
	    fail "${_name}: main tip's install.sh did not install .login_conf"
}

# fetch_count
# Print how many times the last run fetched .profile-repo.
fetch_count() {
	grep -c '^==> \.profile-repo: Fetching$' "${S}/log"
}

test_old() {
	local _rc
	new_scenario old || return 1
	remote_set "${OLD_REV}:master" || return 1
	install_clone || return 1
	remote_set "${FROZEN_REV}:master" "${TIP}:main" HEAD=main || return 1
	run_update_sh
	_rc=$?
	assert_on_tip old "${_rc}"
}

test_workstation() {
	local _rc
	new_scenario workstation || return 1
	remote_set "${FROZEN_REV}:master" || return 1
	install_clone || return 1
	remote_set "${FROZEN_REV}:main" HEAD=main || return 1
	# Revision 1 of git_update, as a host ran it, moves to main and keeps
	# the local master.
	# shellcheck disable=SC2016 # expanded in the sandbox, with its HOME
	sandbox "${S}" sh -c '. "$HOME/.profile-repo/libexec/install-lib.sh" &&
	    git_update prep "$HOME/.profile-repo"' > "${S}/prep.log" 2>&1 ||
	    return 1
	git -C "${S}/home/.profile-repo" rev-parse --quiet --verify \
	    refs/heads/master >/dev/null || return 1
	remote_set "${TIP}:main" || return 1
	run_update_sh
	_rc=$?
	assert_on_tip workstation "${_rc}"
}

test_current() {
	local _rc _n
	new_scenario current || return 1
	remote_set "${FROZEN_REV}:master" "${TIP}:main" HEAD=main || return 1
	install_clone || return 1
	run_update_sh
	_rc=$?
	assert_on_tip current "${_rc}"
	_n="$(fetch_count)"
	case "${_n}" in
	1) ;;
	*) fail "current: fetched .profile-repo ${_n} times, want 1" ;;
	esac
}

build_tip || { echo "FAIL: could not build the code under test" >&2; exit 1; }
for t in test_old test_workstation test_current; do
	_failures_before="${FAILURES}"
	if ! "${t}"; then
		fail "${t}: setup failed"
	fi
	case "${FAILURES}" in
	"${_failures_before}") echo "ok ${t}" ;;
	*)
		echo "not ok ${t}"
		[ -f "${S}/log" ] && grep -E '^==>|HEAD is now at' \
		    "${S}/log" | sed 's/^/# /' >&2
		;;
	esac
done

case "${FAILURES}" in
0) echo "All tests passed" ;;
*) echo "${FAILURES} failure(s)" >&2; exit 1 ;;
esac
