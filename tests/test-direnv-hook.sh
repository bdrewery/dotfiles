#! /bin/sh
# Tests for the direnv block in dot.env.common: the hook it evals must keep
# working after a brew upgrade replaces the versioned Cellar directory the
# shell started on (zsh and bash).
#
# Each case drives a real interactive shell under a pty, with direnv's state
# (HOME and XDG_*) under a temporary directory so the real allow database is
# never touched.
#
# Usage: sh tests/test-direnv-hook.sh [path/to/dot.env.common]
# Dependencies: direnv, zsh, bash and python3 (cases are skipped if absent).

# Re-run under a clean environment: an inherited HISTFILE, DIRENV_* or similar
# would change results or touch the caller's files.
case "${DIRENV_HOOK_TEST_ISOLATED-}" in
1) ;;
*)
	exec env -i PATH="${PATH}" TMPDIR="${TMPDIR:-/tmp}" TERM=xterm \
	    ${LANG:+"LANG=${LANG}"} DIRENV_HOOK_TEST_ISOLATED=1 sh "$0" "$@"
	;;
esac

TESTS_DIR="$(cd "$(dirname "$0")" && pwd -P)" || exit 1
ENV_COMMON="${1:-${TESTS_DIR:?}/../dot.env.common}"

_missing=
for _tool in direnv zsh bash python3; do
	command -v "${_tool}" > /dev/null 2>&1 || _missing="${_missing} ${_tool}"
done
case "${_missing}" in
"") ;;
*) echo "skip: missing${_missing}"; exit 0 ;;
esac

[ -r "${ENV_COMMON}" ] || {
	echo "error: cannot read ${ENV_COMMON}" >&2
	exit 1
}

WORK="$(mktemp -d "${TMPDIR:-/tmp}/test-direnv-hook.XXXXXX")" || exit 1
trap 'rm -rf "${WORK:?}"' EXIT
trap 'exit 1' INT TERM HUP

HOME="${WORK:?}/home"
XDG_DATA_HOME="${WORK:?}/xdg/data"
XDG_CONFIG_HOME="${WORK:?}/xdg/config"
XDG_CACHE_HOME="${WORK:?}/xdg/cache"
TERM=xterm
export HOME XDG_DATA_HOME XDG_CONFIG_HOME XDG_CACHE_HOME TERM
mkdir -p "${HOME:?}" "${XDG_DATA_HOME:?}" "${XDG_CONFIG_HOME:?}" \
    "${XDG_CACHE_HOME:?}" || exit 1

FAILURES=0
SKIPPED=

# fail <message>
# Record a failed assertion.
fail() {
	echo "FAIL: $*" >&2
	FAILURES=$((FAILURES + 1))
}

# build_snippet <zsh|bash> <outfile>
# Write what the shell sources: "_shell_name=<shell>" followed by the direnv
# block of ${ENV_COMMON} (from "if which direnv" through the next "fi").
build_snippet() {
	{
		echo "_shell_name=${1:?}"
		sed -n '/^if which direnv/,/^fi$/p' "${ENV_COMMON:?}"
	} > "${2:?}" || return 1
	[ -s "${2:?}" ] && [ "$(wc -l < "${2:?}")" -gt 2 ] || {
		echo "error: no direnv block in ${ENV_COMMON}" >&2
		return 1
	}
}

# make_envrc <dir> <value>
# Create <dir> holding an .envrc that exports FOO=<value>.
make_envrc() {
	mkdir -p "${1:?}" || return 1
	echo "export FOO=${2:?}" > "${1:?}/.envrc"
}

# foo_cmd <tag>
# Print a shell command that echoes "RESULT<tag> FOO=<value of $FOO>".
foo_cmd() {
	# shellcheck disable=SC2016 # $FOO expands in the driven shell
	printf 'echo "RESULT%s FOO=$FOO"' "${1:?}"
}

# run_shell <case> <zsh|bash> <workdir> <rcfile> <command>...
# Start an interactive <shell> (no user rc files) under a pty in <workdir>,
# source <rcfile>, type each <command> waiting for a fresh prompt after every
# line, then exit. The ANSI/CR-stripped transcript goes to ${WORK}/transcript.
# A line that gets no prompt within 10s fails the case instead of hanging.
# Dependencies: python3.
run_shell() {
	local _case="${1:?}" _sh="${2:?}" _wd="${3:?}" _rc="${4:?}" _status=0
	shift 4
	: > "${WORK:?}/transcript" || return 1
	case "${_sh}" in
	zsh) set -- zsh -f -i -- "$@" ;;
	bash) set -- bash --norc --noprofile -i -- "$@" ;;
	*) fail "${_case}: unknown shell ${_sh}"; return 1 ;;
	esac
	python3 -I - "${_wd}" "${_rc}" "$@" > "${WORK:?}/transcript" <<'PY'
import os, pty, re, select, shlex, signal, sys, time

PROMPT = b"__TEST_PROMPT__ "
TIMEOUT = 10.0
ANSI = re.compile(r"\x1b(\[[0-9;?]*[ -/]*[@-~]|\][^\x07\x1b]*(\x07|\x1b\\)|[()][A-Za-z0-9]|[=>])")

wd, rc = sys.argv[1], sys.argv[2]
sep = sys.argv.index("--")
argv, cmds = sys.argv[3:sep], sys.argv[sep + 1:]

pid, fd = pty.fork()
if pid == 0:
    os.chdir(wd)
    os.environ["PS1"] = PROMPT.decode()
    os.execvp(argv[0], argv)

out = b""


def transcript():
    text = out.decode(errors="replace").replace("\r", "")
    return ANSI.sub("", text)


def die(msg):
    sys.stdout.write(transcript())
    sys.stdout.flush()
    sys.stderr.write("driver: " + msg + "\n")
    try:
        os.kill(pid, signal.SIGKILL)
        os.waitpid(pid, 0)
    except OSError:
        pass
    sys.exit(2)


def read_until(done, what):
    """Read from the pty until done() is true or the timeout expires."""
    global out
    end = time.time() + TIMEOUT
    while not done():
        left = end - time.time()
        if left <= 0:
            die("timeout waiting for " + what)
        if not select.select([fd], [], [], left)[0]:
            continue
        try:
            data = os.read(fd, 65536)
        except OSError:
            data = b""
        if not data:
            die("shell exited while waiting for " + what)
        out += data


want = 1
read_until(lambda: out.count(PROMPT) >= want, "the first prompt")
for line in [". " + shlex.quote(rc)] + cmds:
    os.write(fd, line.encode() + b"\n")
    want += 1
    read_until(lambda: out.count(PROMPT) >= want, "a prompt after: " + line)

os.write(fd, b"exit\n")
end = time.time() + TIMEOUT
while True:
    left = end - time.time()
    if left <= 0:
        die("timeout waiting for the shell to exit")
    if not select.select([fd], [], [], left)[0]:
        continue
    try:
        data = os.read(fd, 65536)
    except OSError:
        data = b""
    if not data:
        break
    out += data
os.waitpid(pid, 0)
sys.stdout.write(transcript())
PY
	_status=$?
	case "${_status}" in
	0) return 0 ;;
	*)
		fail "${_case}: ${_sh} driver exited ${_status}"
		show_transcript
		return 1
		;;
	esac
}

# show_transcript
# Print the last run_shell transcript to stderr, indented.
show_transcript() {
	sed 's/^/    | /' "${WORK:?}/transcript" >&2
}

# assert_result <case> <tag> <want>
# Fail unless the last transcript has a line "RESULT<tag> FOO=<want>" at the
# start of a line (so the echoed command line does not match); the last such
# line wins and a missing line fails. An empty <want> means FOO was unset or
# empty.
assert_result() {
	local _line="" _got=""
	_line="$(sed -n "/^RESULT${2:?} FOO=/p" "${WORK:?}/transcript" | tail -n 1)"
	case "${_line}" in
	"")
		fail "$1: no RESULT$2 line in the transcript"
		show_transcript
		return 0
		;;
	esac
	_got="${_line#"RESULT$2 FOO="}"
	case "${_got}" in
	"${3?}") ;;
	*)
		fail "$1: RESULT$2 FOO='${_got}', want '$3'"
		show_transcript
		;;
	esac
}

# upgrade_case <zsh|bash>
# Simulate "brew upgrade direnv" under a shell that started on the old
# version: a fake prefix whose unversioned bin/direnv is a wrapper exec'ing
# the versioned Cellar copy by absolute path (running it by absolute path
# makes direnv bake in the Cellar path on macOS as symlink resolution does on
# Linux). After cd into dir a, the Cellar dir is renamed to the new version
# and the wrapper rewritten; cd into dir b must still load b's .envrc without
# a "no such file" error.
upgrade_case() {
	local _sh="${1:?}" _case="upgrade_${1:?}" _w="${WORK:?}/upgrade_${1:?}"
	local _p="${_w}/prefix" _real=
	if ! direnv version 2.38.0 > /dev/null 2>&1; then
		echo "skip ${_case}: needs direnv >= 2.38 (DIRENV_EXE_PATH)"
		SKIPPED=1
		return 0
	fi
	_real="$(readlink -f "$(command -v direnv)")" || return 1
	mkdir -p "${_p}/Cellar/direnv/2.38.1/bin" "${_p}/bin" || return 1
	cp "${_real}" "${_p}/Cellar/direnv/2.38.1/bin/direnv" || return 1
	printf '#!/bin/sh\nexec '"'"'%s'"'"' "$@"\n' \
	    "${_p}/Cellar/direnv/2.38.1/bin/direnv" > "${_p}/bin/direnv" ||
	    return 1
	printf '#!/bin/sh\nexec '"'"'%s'"'"' "$@"\n' \
	    "${_p}/Cellar/direnv/2.38.2/bin/direnv" > "${_p}/bin/direnv.new" ||
	    return 1
	chmod +x "${_p}/bin/direnv" "${_p}/bin/direnv.new" || return 1
	make_envrc "${_w}/a" a || return 1
	make_envrc "${_w}/b" b || return 1
	(
		PATH="${_p}/bin:${PATH}"
		direnv allow "${_w}/a" && direnv allow "${_w}/b" &&
		    run_shell "${_case}" "${_sh}" "${_w}" "${WORK:?}/snippet.${_sh}" \
		    'cd a' \
		    "$(foo_cmd 1)" \
		    "mv '${_p}/Cellar/direnv/2.38.1' '${_p}/Cellar/direnv/2.38.2'; mv '${_p}/bin/direnv.new' '${_p}/bin/direnv'" \
		    'cd ../b' \
		    "$(foo_cmd 2)"
	) || {
		fail "${_case}: setup or shell driver failed"
		show_transcript
		return 0
	}
	assert_result "${_case}" 1 a
	assert_result "${_case}" 2 b
	if grep -aiq 'no such file' "${WORK:?}/transcript"; then
		fail "${_case}: transcript has a 'no such file' error"
		show_transcript
	fi
}

# test_bash_alias_direnv
# With "direnv" aliased to its absolute path, the hook still works: the
# alias text from "command -v" must not be baked in as direnv's path.
test_bash_alias_direnv() {
	local _d="${WORK:?}/alias_direnv" _real=
	_real="$(command -v direnv)" || return 1
	case "${_real}" in
	/*) ;;
	*) return 1 ;;
	esac
	make_envrc "${_d}" aliased1 || return 1
	direnv allow "${_d}" || return 1
	{
		printf "alias direnv='%s'\n" "${_real}"
		cat "${WORK:?}/snippet.bash"
	} > "${WORK:?}/snippet.alias" || return 1
	run_shell bash_alias_direnv bash "${_d}" "${WORK:?}/snippet.alias" \
	    "$(foo_cmd 1)" || return 0
	assert_result bash_alias_direnv 1 aliased1
	if grep -aiqE 'not found|no such file' "${WORK:?}/transcript"; then
		fail "bash_alias_direnv: transcript has a 'not found' or 'no such file' error"
		show_transcript
	fi
}

test_zsh_upgrade() { upgrade_case zsh; }
test_bash_upgrade() { upgrade_case bash; }

build_snippet zsh "${WORK:?}/snippet.zsh" || exit 1
build_snippet bash "${WORK:?}/snippet.bash" || exit 1

for t in test_zsh_upgrade test_bash_upgrade test_bash_alias_direnv; do
	_failures_before="${FAILURES}"
	SKIPPED=
	: > "${WORK:?}/transcript" || exit 1
	if ! "${t}"; then
		fail "${t}: setup failed"
	fi
	case "${FAILURES}:${SKIPPED}" in
	"${_failures_before}:") echo "ok ${t}" ;;
	"${_failures_before}:1") echo "skip ${t}" ;;
	*) echo "not ok ${t}" ;;
	esac
done

case "${FAILURES}" in
0) echo "All tests passed" ;;
*) echo "${FAILURES} failure(s)" >&2; exit 1 ;;
esac
