#! /bin/sh
# End-to-end test of update-profile (update.sh -> git_update -> install.sh)
# across the master -> main rename.
#
# The real update.sh and install.sh run against a stand-in remote inside
# bwrap (see sandbox()), so that they cannot:
#  - modify anything outside the scratch directory: the root, including the
#    caller's $HOME, is read-only, and $HOME is hidden behind an empty
#    read-only mount;
#  - start services: /run, with the session bus and docker socket, is
#    hidden;
#  - leave anything running: the sandbox has its own process tree, and
#    whatever is left in it is killed when the command exits.
# test_sandbox_isolation checks all three before any scenario runs, and the
# test stops if it fails.  The sandbox is also offline, and its environment
# is cleared apart from HOME, PATH, TMPDIR, TERM and LANG; an inherited
# PROFILE_REPO would otherwise point update.sh at the real ~/.profile-repo.
# PATH entries under $HOME are dropped.  Offline, submodule clones and pip
# installs fail; both are reported and the install goes on, as on an
# offline host.
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
#   no-update    install.sh -N, as Ansible runs it after checking out
#                .profile-repo itself, with no revision marker: must install
#                that checkout without fetching or changing it.  An unknown
#                option must fail without doing anything, and -n -N must
#                neither fetch nor rebuild zsh completions.
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
case "${HOME:-/}" in
/)
	echo "FAIL: HOME must be set to a directory other than /" >&2
	exit 1
	;;
esac
REAL_HOME="${HOME}"
REPO_ROOT="$(cd "${TESTS_DIR:?}/.." && pwd -P)" || exit 1

# Keep the caller's git environment out, such as GIT_DIR from a hook, so
# git commands act only on the repos named here.
# shellcheck disable=SC2046 # one variable name per word
unset $(git rev-parse --local-env-vars) GIT_TEMPLATE_DIR

if ! command -v bwrap >/dev/null 2>&1; then
	echo "skip: bwrap is not installed"
	exit 0
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
# Run <command> (an absolute path) isolated as described at the top, with
# HOME=<dir>/home and <dir> writable.  The tmpfs mounts come before the
# bind so <dir> stays reachable even under /tmp or $HOME, and the empty
# $HOME is made read-only after it.
sandbox() {
	local _s="${1:?}"
	shift
	bwrap --unshare-all --new-session --die-with-parent \
	    --ro-bind / / --dev /dev --proc /proc \
	    --tmpfs /run --tmpfs /tmp --tmpfs "${REAL_HOME:?}" \
	    --bind "${_s}" "${_s}" --remount-ro "${REAL_HOME}" \
	    --clearenv --setenv HOME "${_s}/home" \
	    --setenv PATH "${SANDBOX_PATH}" --setenv TMPDIR "${_s}/tmp" \
	    --setenv TERM dumb --setenv LANG C.UTF-8 \
	    "$@" </dev/null
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
	sandbox "${S}" /bin/sh "${S}/home/.profile-repo/update.sh" \
	    > "${S}/log" 2>&1
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

# The sandbox must keep writes inside the scratch directory, hide the
# session bus and other /run sockets, and kill whatever is left running.
test_sandbox_isolation() {
	local _out _tag _i
	S="${WORK:?}/isolation"
	mkdir -p "${S}/home" "${S}/tmp" || return 1
	_tag="299.$$"
	# The background sleep must be seen running inside before the host
	# checks that it is gone, so a sleep that never started cannot pass.
	# shellcheck disable=SC2016 # expanded in the sandbox
	_out="$(sandbox "${S}" /bin/sh -c '
		( : > "$1/.test-update-e2e-probe" ) 2>/dev/null &&
		    echo "real HOME writable"
		( : > /usr/.test-update-e2e-probe ) 2>/dev/null &&
		    echo "root filesystem writable"
		[ -z "$(ls -A /run)" ] || echo "/run visible"
		setsid sleep "$2" </dev/null >/dev/null 2>&1 &
		i=0
		until pgrep -f "sleep $2" >/dev/null; do
			i=$((i + 1))
			if [ "${i}" -gt 50 ]; then
				echo "background probe did not start"
				break
			fi
			sleep 0.1
		done
		echo "sandbox ok"
	    ' sh "${REAL_HOME}" "${_tag}" 2>&1)" || {
		fail "isolation: bwrap failed: ${_out}"
		return 0
	}
	case "${_out}" in
	"sandbox ok") ;;
	*) fail "isolation: ${_out}" ;;
	esac
	[ -e "${REAL_HOME}/.test-update-e2e-probe" ] &&
	    fail "isolation: probe file reached the real HOME"
	[ -e /usr/.test-update-e2e-probe ] &&
	    fail "isolation: probe file reached /usr"
	# The kernel kills the namespace's processes as bwrap exits; allow
	# a moment for them to go.
	_i=0
	while pgrep -f "sleep ${_tag}" >/dev/null 2>&1; do
		_i=$((_i + 1))
		if [ "${_i}" -gt 20 ]; then
			fail "isolation: background process outlived the sandbox"
			pkill -f "sleep ${_tag}"
			break
		fi
		sleep 0.1
	done
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
	sandbox "${S}" /bin/sh -c '. "$HOME/.profile-repo/libexec/install-lib.sh" &&
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

# Ansible checks out .profile-repo itself and runs install.sh -N without
# the revision marker update.sh would set.  install.sh must install the
# checkout as it is: no fetch, and HEAD and every ref left alone, even with
# main moved on upstream and a stray local branch present.
test_install_no_update() {
	local _rc _repo _newer _before _after
	new_scenario no-update || return 1
	remote_set "${FROZEN_REV}:master" "${TIP}:main" HEAD=main || return 1
	install_clone || return 1
	_repo="${S}/home/.profile-repo"
	git -C "${_repo}" branch master || return 1
	_newer="$(git -C "${WORK}/src" commit-tree "${TIP}^{tree}" -p "${TIP}" \
	    -m "test: main moved on")" || return 1
	remote_set "${_newer}:main" || return 1
	_before="$(refs_state "${_repo}")" || return 1
	sandbox "${S}" /bin/sh "${_repo}/install.sh" -x > "${S}/log" 2>&1
	_rc=$?
	case "${_rc}" in
	64) ;;
	*) fail "no-update: install.sh -x exited ${_rc}, want 64" ;;
	esac
	sandbox "${S}" /bin/sh "${_repo}/install.sh" -n -N >> "${S}/log" 2>&1 ||
	    fail "no-update: install.sh -n -N exited $?"
	[ -e "${S}/home/.zcompdump" ] &&
	    fail "no-update: install.sh -n rebuilt zsh completions"
	# Ansible runs it with bash.
	sandbox "${S}" /bin/bash "${_repo}/install.sh" -N >> "${S}/log" 2>&1
	_rc=$?
	case "${_rc}" in
	0) ;;
	*) fail "no-update: install.sh -N exited ${_rc}" ;;
	esac
	_after="$(refs_state "${_repo}")" || return 1
	case "${_after}" in
	"${_before}") ;;
	*) fail "no-update: checkout changed: ${_before} -> ${_after}" ;;
	esac
	if grep -q ': Fetching$' "${S}/log"; then
		fail "no-update: install.sh fetched"
	fi
	grep -qxF "${MARKER}" "${S}/home/.login_conf" ||
	    fail "no-update: install.sh -N did not install"
}

# refs_state <repo>
# Print HEAD and every ref of <repo> on one line.
refs_state() {
	printf '%s %s ' "$(git -C "${1:?}" symbolic-ref -q HEAD)" \
	    "$(git -C "${1:?}" rev-parse HEAD)" &&
	    git -C "${1:?}" for-each-ref --format='%(refname)=%(objectname)' |
	    tr '\n' ' '
}

build_tip || { echo "FAIL: could not build the code under test" >&2; exit 1; }
test_sandbox_isolation
case "${FAILURES}" in
0) echo "ok test_sandbox_isolation" ;;
*)
	echo "not ok test_sandbox_isolation"
	echo "FAIL: sandbox is not isolated; not running the installer" >&2
	exit 1
	;;
esac
for t in test_old test_workstation test_current test_install_no_update; do
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
