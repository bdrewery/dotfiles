#! /bin/sh
# Tests for sync_dir in libexec/install-lib.sh.
#
# Usage: sh tests/test-sync-dir.sh
# Dependencies: rsync and POSIX utilities.

TESTS_DIR="$(cd "$(dirname "$0")" && pwd -P)" || exit 1
# shellcheck source=libexec/install-lib.sh
. "${TESTS_DIR:?}/../libexec/install-lib.sh" || exit 1

WORK="$(mktemp -d "${TMPDIR:-/tmp}/test-sync-dir.XXXXXX")" || exit 1
trap 'rm -rf "${WORK:?}"' EXIT
trap 'exit 1' INT TERM HUP

FAILURES=0

# fail <message>
# Record a failed assertion.
fail() {
	echo "FAIL: $*" >&2
	FAILURES=$((FAILURES + 1))
}

# setup_case <name>
# Start a fresh HOME with ${REPO}/dot.config holding a/keep, a/skip,
# b/skip and top.  Sets CASE, HOME and REPO.
setup_case() {
	local _f
	CASE="${WORK:?}/${1:?}"
	HOME="${CASE:?}/home"
	REPO=repo
	mkdir -p "${HOME:?}/${REPO:?}/dot.config/a" \
	    "${HOME:?}/${REPO:?}/dot.config/b" || return 1
	for _f in a/keep a/skip b/skip top; do
		echo "${_f}" > "${HOME:?}/${REPO:?}/dot.config/${_f}" ||
		    return 1
	done
}

# run_sync <args...>
# Run sync_dir from HOME.  Sets RC.
run_sync() {
	(
		cd "${HOME:?}" || exit 1
		sync_dir "$@"
	) > "${CASE:?}/out" 2>&1
	RC=$?
}

# assert_copied <path...>
assert_copied() {
	local _f
	for _f in "$@"; do
		[ -f "${HOME:?}/.config/${_f}" ] ||
		    fail "${CASE##*/}: ${_f} not copied"
	done
}

# assert_skipped <path...>
assert_skipped() {
	local _f
	for _f in "$@"; do
		[ ! -e "${HOME:?}/.config/${_f}" ] ||
		    fail "${CASE##*/}: ${_f} copied despite exclude"
	done
}

test_no_exclude() {
	setup_case no_exclude || return 1
	run_sync dot.config .config
	[ "${RC}" -eq 0 ] || fail "no_exclude: returned ${RC}"
	assert_copied a/keep a/skip b/skip top
}

test_one_exclude() {
	setup_case one_exclude || return 1
	run_sync --exclude /a/skip dot.config .config
	[ "${RC}" -eq 0 ] || fail "one_exclude: returned ${RC}"
	assert_copied a/keep b/skip top
	assert_skipped a/skip
}

test_repeated_exclude() {
	setup_case repeated_exclude || return 1
	run_sync --exclude /a/skip --exclude /b/ dot.config .config
	[ "${RC}" -eq 0 ] || fail "repeated_exclude: returned ${RC}"
	assert_copied a/keep top
	assert_skipped a/skip b
}

test_missing_exclude_pattern() {
	setup_case missing_pattern || return 1
	run_sync dot.config .config --exclude
	[ "${RC}" -ne 0 ] || fail "missing_pattern: accepted trailing option"
	run_sync --exclude
	[ "${RC}" -ne 0 ] || fail "missing_pattern: accepted --exclude alone"
}

for t in test_no_exclude test_one_exclude test_repeated_exclude \
    test_missing_exclude_pattern; do
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
