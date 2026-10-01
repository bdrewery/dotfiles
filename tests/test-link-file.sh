#! /bin/sh
# Tests for link_file in libexec/install-lib.sh: what it does with a file
# already at the destination it is about to replace.
#
# Each case runs in a scratch HOME under a temporary directory.
#
# Usage: sh tests/test-link-file.sh
# Dependencies: POSIX utilities; no network access.

TESTS_DIR="$(cd "$(dirname "$0")" && pwd -P)" || exit 1
# shellcheck source=libexec/install-lib.sh
. "${TESTS_DIR:?}/../libexec/install-lib.sh" || exit 1

WORK="$(mktemp -d "${TMPDIR:-/tmp}/test-link-file.XXXXXX")" || exit 1
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
# Point HOME at a fresh ${WORK}/<name> holding a repo at ${REPO} with
# dot.bashrc and dot.claude/CLAUDE.global.md, and cd into it as
# install-lib.sh's callers do.
setup_case() {
	HOME="${WORK:?}/${1:?}"
	REPO=".profile-repo"
	mkdir -p "${HOME:?}/${REPO:?}/dot.claude" "${HOME:?}/.claude" ||
	    return 1
	echo repo-bashrc > "${HOME:?}/${REPO:?}/dot.bashrc" || return 1
	echo repo-claude > "${HOME:?}/${REPO:?}/dot.claude/CLAUDE.global.md" ||
	    return 1
	cd "${HOME:?}" || return 1
}

# assert_linked <case> <dest> <target>
# Fail unless ~/<dest> is a symlink to <target>.
assert_linked() {
	local _got=
	[ -L "${HOME:?}/${2:?}" ] || {
		fail "$1: ~/$2 is not a symlink"
		return 0
	}
	_got="$(readlink "${HOME:?}/${2:?}")"
	case "${_got}" in
	"${3:?}") ;;
	*) fail "$1: ~/$2 -> ${_got}, want $3" ;;
	esac
}

# assert_content <case> <file> <content>
# Fail unless ~/<file> is a regular file holding exactly <content>.
assert_content() {
	if [ -L "${HOME:?}/${2:?}" ] || [ ! -f "${HOME:?}/${2:?}" ]; then
		fail "$1: ~/$2 is not a regular file"
		return 0
	fi
	case "$(cat "${HOME:?}/${2:?}")" in
	"${3?}") ;;
	*) fail "$1: ~/$2 holds '$(cat "${HOME:?}/${2:?}")', want '$3'" ;;
	esac
}

# count_replaced <file>
# Print how many ~/<file>.profile-repo-* backups _replace left.
count_replaced() {
	local _f _n=0
	for _f in "${HOME:?}/${1:?}".profile-repo-*; do
		[ -e "${_f}" ] && _n=$((_n + 1))
	done
	printf '%d' "${_n}"
}

test_default_dest_preserves() {
	setup_case default_dest_preserves || return 1
	echo mine > .bashrc || return 1
	link_file dot.bashrc > /dev/null || fail "default_dest: link_file failed"
	assert_linked default_dest .bashrc ".profile-repo/dot.bashrc"
	assert_content default_dest .bashrc.local mine
}

test_explicit_dest_preserves() {
	setup_case explicit_dest_preserves || return 1
	echo mine > .claude/CLAUDE.md || return 1
	link_file dot.claude/CLAUDE.global.md .claude/CLAUDE.md > /dev/null ||
	    fail "explicit_dest: link_file failed"
	assert_linked explicit_dest .claude/CLAUDE.md \
	    "../.profile-repo/dot.claude/CLAUDE.global.md"
	assert_content explicit_dest .claude/CLAUDE.md.local mine
}

test_explicit_dest_existing_local() {
	setup_case explicit_dest_existing_local || return 1
	echo mine > .claude/CLAUDE.md || return 1
	echo older > .claude/CLAUDE.md.local || return 1
	link_file dot.claude/CLAUDE.global.md .claude/CLAUDE.md > /dev/null ||
	    fail "existing_local: link_file failed"
	assert_linked existing_local .claude/CLAUDE.md \
	    "../.profile-repo/dot.claude/CLAUDE.global.md"
	assert_content existing_local .claude/CLAUDE.md.local older
	case "$(count_replaced .claude/CLAUDE.md)" in
	1) ;;
	*) fail "existing_local: want 1 .profile-repo-* backup of ~/.claude/CLAUDE.md, got $(count_replaced .claude/CLAUDE.md)" ;;
	esac
}

test_explicit_dest_leaves_src_name() {
	setup_case explicit_dest_leaves_src_name || return 1
	echo unrelated > .claude/CLAUDE.global.md || return 1
	link_file dot.claude/CLAUDE.global.md .claude/CLAUDE.md > /dev/null ||
	    fail "leaves_src_name: link_file failed"
	assert_content leaves_src_name .claude/CLAUDE.global.md unrelated
	[ -e .claude/CLAUDE.global.md.local ] &&
	    fail "leaves_src_name: ~/.claude/CLAUDE.global.md.local was created"
	return 0
}

test_repo_symlink_replaced() {
	setup_case repo_symlink_replaced || return 1
	ln -s "../.profile-repo/dot.claude/old.md" .claude/CLAUDE.md ||
	    return 1
	link_file dot.claude/CLAUDE.global.md .claude/CLAUDE.md > /dev/null ||
	    fail "repo_symlink: link_file failed"
	assert_linked repo_symlink .claude/CLAUDE.md \
	    "../.profile-repo/dot.claude/CLAUDE.global.md"
	[ -e .claude/CLAUDE.md.local ] || [ -L .claude/CLAUDE.md.local ] &&
	    fail "repo_symlink: ~/.claude/CLAUDE.md.local was created"
	case "$(count_replaced .claude/CLAUDE.md)" in
	0) ;;
	*) fail "repo_symlink: ~/.claude/CLAUDE.md was backed up" ;;
	esac
}

for t in test_default_dest_preserves test_explicit_dest_preserves \
    test_explicit_dest_existing_local test_explicit_dest_leaves_src_name \
    test_repo_symlink_replaced; do
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
