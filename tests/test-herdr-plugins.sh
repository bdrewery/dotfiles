#! /bin/sh
# Tests for install_herdr_plugins in libexec/install-lib.sh.
#
# A fake herdr stands in for the real one.  It records every call and keeps
# a plugin registry shaped like `herdr plugin list --json`, refusing the
# same things the real CLI refuses: unlink, enable, disable and action
# invoke need a running server; install refuses over a local link.
#
# Usage: sh tests/test-herdr-plugins.sh
# Dependencies: jq and POSIX utilities; no network access.

TESTS_DIR="$(cd "$(dirname "$0")" && pwd -P)" || exit 1
# shellcheck source=libexec/install-lib.sh
. "${TESTS_DIR:?}/../libexec/install-lib.sh" || exit 1

JQ_REAL="$(command -v jq)" || {
	echo "test-herdr-plugins: jq is required" >&2
	exit 1
}

WORK="$(mktemp -d "${TMPDIR:-/tmp}/test-herdr-plugins.XXXXXX")" || exit 1
trap 'rm -rf "${WORK:?}"' EXIT
trap 'exit 1' INT TERM HUP

FAILURES=0
TAB="$(printf '\t')"

# fail <message>
# Record a failed assertion.
fail() {
	echo "FAIL: $*" >&2
	FAILURES=$((FAILURES + 1))
}

# sha <hexdigit>
# Print a 40-character commit hash made of <hexdigit>.
sha() {
	printf '%040d' 0 | tr 0 "${1:?}"
}

# make_sys_path
# Populate ${WORK}/sys with links to the system tools the installer may use,
# leaving out herdr and jq so each case can choose whether they exist.
make_sys_path() {
	local _tool _path
	mkdir -p "${WORK:?}/sys" || return 1
	for _tool in awk cat chmod cmp cp cut date dirname env find grep \
	    install ln ls mkdir mktemp mv readlink rm rsync sed sh sort tr \
	    uname wc; do
		_path="$(command -v "${_tool}")" || continue
		ln -s "${_path:?}" "${WORK:?}/sys/${_tool}" || return 1
	done
}

# write_fake_herdr <path>
# Write the fake herdr to <path>.  State lives in ${FAKE_HERDR_DIR}:
#   calls           one line per invocation, arguments joined by spaces
#   registry.json   array of {plugin_id, enabled, source}
#   sources         "<owner/repo> <plugin_id>" for sources install knows
#   server          exists while the server is "running"
#   fail-list       exists to make plugin list fail
#   fail-install    sources whose install fails
#   fail-uninstall  ids whose uninstall fails
#   fail-action     action ids whose invoke fails
write_fake_herdr() {
	cat > "${1:?}" <<-'EOF' || return 1
		#! /bin/sh
		D="${FAKE_HERDR_DIR:?}"
		JQ="${FAKE_JQ:?}"
		REG="${D}/registry.json"
		[ -f "${REG}" ] || echo '[]' > "${REG}"
		echo "$*" >> "${D}/calls"
		# Drain stdin, so a caller that lets herdr read its loop
		# input loses the rest of the list.
		cat > /dev/null
		listed() {
			grep -qxF "$1" "${D}/$2" 2>/dev/null
		}
		need_server() {
			[ -e "${D}/server" ] && return 0
			echo '{"error":{"code":"server_not_running"}}'
			exit 1
		}
		update() {
			"${JQ}" "$@" "${REG}" > "${REG}.tmp" &&
			    mv "${REG}.tmp" "${REG}"
		}
		registered() {
			"${JQ}" -e --arg id "$1" --arg k "$2" \
			    'any(.[]; .plugin_id == $id and
			        ($k == "" or .source.kind == $k))' \
			    "${REG}" >/dev/null
		}
		case "$1 $2" in
		"status server")
			if [ -e "${D}/server" ]; then
				echo '{"status":"running","running":true}'
			else
				echo '{"status":"not_running","running":false}'
			fi
			;;
		"plugin list")
			if [ -e "${D}/fail-list" ]; then
				echo "list failed" >&2
				exit 1
			fi
			"${JQ}" '{id: "cli:plugin", result: {plugins: .}}' "${REG}"
			;;
		"plugin install")
			src="$3"
			ref="$5"
			if listed "${src}" fail-install; then
				echo "build failed: ${src}" >&2
				exit 1
			fi
			id="$(awk -v s="${src}" '$1 == s {print $2}' "${D}/sources")"
			if [ -z "${id}" ]; then
				echo "no such repository: ${src}" >&2
				exit 1
			fi
			if registered "${id}" local; then
				echo "refusing to replace locally linked ${id}" >&2
				exit 1
			fi
			update --arg id "${id}" --arg o "${src%%/*}" \
			    --arg r "${src#*/}" --arg ref "${ref}" \
			    --arg c "$(printf '%040d' 0)" \
			    '[.[] | select(.plugin_id != $id)] + [{plugin_id: $id,
			      enabled: true, source: {kind: "github", owner: $o,
			      repo: $r, requested_ref: $ref,
			      resolved_commit: $c}}]'
			echo "Plugin install preview: NOISE"
			echo "Installed ${id} from ${src}."
			;;
		"plugin uninstall")
			if listed "$3" fail-uninstall; then
				echo "uninstall failed: $3" >&2
				exit 1
			fi
			if ! registered "$3" ""; then
				echo "plugin not installed: $3" >&2
				exit 1
			fi
			update --arg id "$3" '[.[] | select(.plugin_id != $id)]'
			;;
		"plugin unlink")
			need_server
			update --arg id "$3" '[.[] | select(.plugin_id != $id)]'
			;;
		"plugin enable"|"plugin disable")
			need_server
			update --arg id "$3" --argjson e \
			    "$([ "$2" = enable ] && echo true || echo false)" \
			    'map(if .plugin_id == $id then .enabled = $e else . end)'
			;;
		"plugin action")
			need_server
			if listed "$4" fail-action; then
				echo "action failed: $4" >&2
				exit 1
			fi
			echo '{"result":{"type":"plugin_action_invoked","NOISE":1}}'
			;;
		*)
			echo "fake herdr: unexpected call: $*" >&2
			exit 2
			;;
		esac
	EOF
	chmod +x "${1:?}"
}

# setup_case <name>
# Start a fresh HOME, repo and fake herdr for one test case.  The server
# is running and the sources o/a, o/b, o/c map to plugin ids a.id, b.id,
# c.id.  Sets CASE, HOME, REPO, FAKE_HERDR_DIR, BIN and LIST.
setup_case() {
	CASE="${WORK:?}/${1:?}"
	HOME="${CASE:?}/home"
	REPO=repo
	FAKE_HERDR_DIR="${CASE:?}/fake"
	BIN="${CASE:?}/bin"
	LIST="${HOME:?}/${REPO:?}/dot.config/herdr/plugins.list"
	STATE="${HOME:?}/.config/herdr/profile-repo/plugins.list"
	mkdir -p "${HOME:?}/${REPO:?}/dot.config/herdr" \
	    "${FAKE_HERDR_DIR:?}" "${BIN:?}" || return 1
	: > "${FAKE_HERDR_DIR:?}/calls" || return 1
	echo '[]' > "${FAKE_HERDR_DIR:?}/registry.json" || return 1
	touch "${FAKE_HERDR_DIR:?}/server" || return 1
	cat > "${FAKE_HERDR_DIR:?}/sources" <<-EOF || return 1
		o/a a.id
		o/b b.id
		o/c c.id
	EOF
	write_fake_herdr "${BIN:?}/herdr" || return 1
	ln -s "${JQ_REAL:?}" "${BIN:?}/jq" || return 1
	FAKE_JQ="${JQ_REAL:?}"
	export FAKE_HERDR_DIR FAKE_JQ
}

# entry <id> <source> <ref> <state> [action]
# Print one plugins.list line.
entry() {
	printf '%s\t%s\t%s\t%s%s\n' "${1}" "${2}" "${3}" "${4}" \
	    "${5:+${TAB}${5}}"
}

# registry <json-array>
# Replace the fake herdr's registry.
registry() {
	printf '%s\n' "${1:?}" > "${FAKE_HERDR_DIR:?}/registry.json"
}

# github_plugin <id> <owner/repo> <requested_ref> [enabled] [commit]
# Print a registry entry for a GitHub install of <requested_ref>, which
# resolved to [commit] (default: all zeros).  An empty <requested_ref>
# leaves it out, as installs from before herdr recorded it do.
github_plugin() {
	printf '{"plugin_id":"%s","enabled":%s,"source":{"kind":"github",' \
	    "${1:?}" "${4:-true}"
	printf '"owner":"%s","repo":"%s",' "${2%%/*}" "${2#*/}"
	case "${3:+set}" in
	set) printf '"requested_ref":"%s",' "${3}" ;;
	esac
	printf '"resolved_commit":"%s"}}' "${5:-$(sha 0)}"
}

# local_plugin <id>
# Print a registry entry for a locally linked plugin.
local_plugin() {
	printf '{"plugin_id":"%s","enabled":true,"source":{"kind":"local"}}' \
	    "${1:?}"
}

# server_down
# Stop the fake herdr server.
server_down() {
	rm -f "${FAKE_HERDR_DIR:?}/server"
}

# run_install [path]
# Run install_herdr_plugins from HOME with PATH set to [path] (default:
# the case's bin directory then system tools).  Sets RC; output is kept in
# ${CASE}/out.  stdin is /dev/null so the fake herdr's drain cannot block.
run_install() {
	local _path="${1:-${BIN:?}:${WORK:?}/sys}"
	(
		cd "${HOME:?}" || exit 1
		PATH="${_path:?}"
		install_herdr_plugins
	) > "${CASE:?}/out" 2>&1 < /dev/null
	RC=$?
}

# called <call>
# Succeed if the fake herdr was invoked with exactly <call>.
called() {
	grep -qxF "${1:?}" "${FAKE_HERDR_DIR:?}/calls"
}

# assert_called <call>
assert_called() {
	called "${1:?}" ||
	    fail "${CASE##*/}: expected call '${1}'; calls: $(tr '\n' ';' \
	    < "${FAKE_HERDR_DIR:?}/calls")"
}

# assert_not_called <call>
assert_not_called() {
	! called "${1:?}" ||
	    fail "${CASE##*/}: unexpected call '${1}'"
}

# assert_no_mutation
# Fail if herdr was asked for anything but status and list.
assert_no_mutation() {
	local _extra
	_extra="$(grep -v -e '^status server' -e '^plugin list' \
	    "${FAKE_HERDR_DIR:?}/calls")"
	case "${_extra:+set}" in
	set) fail "${CASE##*/}: unexpected calls: ${_extra}" ;;
	esac
}

# assert_rc <0|nonzero>
assert_rc() {
	case "${1:?}:${RC:?}" in
	0:0) ;;
	nonzero:0) fail "${CASE##*/}: expected failure; output: $(cat \
	    "${CASE:?}/out")" ;;
	nonzero:*) ;;
	*) fail "${CASE##*/}: returned ${RC}; output: $(cat "${CASE:?}/out")" ;;
	esac
}

# assert_state <expected-file>
# The recorded installed list must match <expected-file> byte for byte.
assert_state() {
	if [ ! -f "${STATE:?}" ]; then
		fail "${CASE##*/}: ${STATE} was not written"
	elif ! cmp -s "${1:?}" "${STATE:?}"; then
		fail "${CASE##*/}: recorded list differs: $(cat "${STATE}")"
	fi
}

test_installs_missing() {
	setup_case installs_missing || return 1
	entry a.id o/a "$(sha a)" enable restart > "${LIST:?}"
	run_install
	assert_rc 0
	assert_called "plugin install o/a --ref $(sha a) --yes"
	assert_called "plugin action invoke a.id.restart"
	assert_not_called "plugin enable a.id"
	assert_state "${LIST:?}"
}

test_up_to_date_is_noop() {
	setup_case up_to_date || return 1
	entry a.id o/a "$(sha a)" enable restart > "${LIST:?}"
	registry "[$(github_plugin a.id o/a "$(sha a)")]"
	run_install
	assert_rc 0
	assert_no_mutation
	assert_state "${LIST:?}"
}

test_tag_installs() {
	setup_case tag_installs || return 1
	entry a.id o/a v1.2.0 enable > "${LIST:?}"
	run_install
	assert_rc 0
	assert_called "plugin install o/a --ref v1.2.0 --yes"
	assert_state "${LIST:?}"
}

test_tag_up_to_date() {
	setup_case tag_up_to_date || return 1
	entry a.id o/a v1.2.0 enable restart > "${LIST:?}"
	registry "[$(github_plugin a.id o/a v1.2.0 true "$(sha a)")]"
	run_install
	assert_rc 0
	assert_no_mutation
}

test_reinstalls_other_tag() {
	setup_case other_tag || return 1
	entry a.id o/a v1.2.0 enable restart > "${LIST:?}"
	registry "[$(github_plugin a.id o/a v1.1.0 true "$(sha a)")]"
	run_install
	assert_rc 0
	assert_called "plugin install o/a --ref v1.2.0 --yes"
	assert_called "plugin action invoke a.id.restart"
}

test_commit_matches_unrecorded_ref() {
	setup_case unrecorded_ref || return 1
	entry a.id o/a "$(sha a)" enable restart > "${LIST:?}"
	registry "[$(github_plugin a.id o/a "" true "$(sha a)")]"
	run_install
	assert_rc 0
	assert_no_mutation
}

test_quiet_success() {
	setup_case quiet_success || return 1
	entry a.id o/a v1.2.0 enable restart > "${LIST:?}"
	run_install
	assert_rc 0
	assert_called "plugin action invoke a.id.restart"
	if grep -q NOISE "${CASE:?}/out"; then
		fail "quiet_success: herdr output shown: $(cat "${CASE:?}/out")"
	fi
}

test_failure_shows_herdr_output() {
	setup_case failure_output || return 1
	entry a.id o/a v1.2.0 enable > "${LIST:?}"
	echo o/a > "${FAKE_HERDR_DIR:?}/fail-install"
	run_install
	assert_rc nonzero
	if ! grep -q 'build failed: o/a' "${CASE:?}/out"; then
		fail "failure_output: herdr's error not shown: $(cat \
		    "${CASE:?}/out")"
	fi
}

test_reinstalls_other_commit() {
	setup_case other_commit || return 1
	entry a.id o/a "$(sha a)" enable restart > "${LIST:?}"
	registry "[$(github_plugin a.id o/a "$(sha b)")]"
	run_install
	assert_rc 0
	assert_called "plugin install o/a --ref $(sha a) --yes"
	assert_not_called "plugin uninstall a.id"
	assert_called "plugin action invoke a.id.restart"
}

test_replaces_local_link() {
	setup_case local_link || return 1
	entry a.id o/a "$(sha a)" enable > "${LIST:?}"
	registry "[$(local_plugin a.id)]"
	run_install
	assert_rc 0
	assert_called "plugin unlink a.id"
	assert_called "plugin install o/a --ref $(sha a) --yes"
	case "$(grep -n -e '^plugin unlink a.id$' -e '^plugin install o/a ' \
	    "${FAKE_HERDR_DIR:?}/calls" | cut -d: -f1 | tr '\n' ' ')" in
	"2 3 "|"3 4 ") ;;
	*) fail "local_link: unlink must precede install: $(tr '\n' ';' \
	    < "${FAKE_HERDR_DIR:?}/calls")" ;;
	esac
}

test_local_link_without_server() {
	setup_case local_link_no_server || return 1
	entry a.id o/a "$(sha a)" enable > "${LIST:?}"
	registry "[$(local_plugin a.id)]"
	server_down
	run_install
	assert_rc nonzero
	assert_not_called "plugin unlink a.id"
	assert_not_called "plugin install o/a --ref $(sha a) --yes"
}

test_replaces_other_source() {
	setup_case other_source || return 1
	entry a.id o/a "$(sha a)" enable > "${LIST:?}"
	registry "[$(github_plugin a.id elsewhere/a "$(sha a)")]"
	run_install
	assert_rc 0
	assert_called "plugin install o/a --ref $(sha a) --yes"
}

test_disables() {
	setup_case disables || return 1
	entry a.id o/a "$(sha a)" disable > "${LIST:?}"
	registry "[$(github_plugin a.id o/a "$(sha a)" true)]"
	run_install
	assert_rc 0
	assert_called "plugin disable a.id"
}

test_disables_after_install() {
	setup_case disables_after_install || return 1
	entry a.id o/a "$(sha a)" disable restart > "${LIST:?}"
	run_install
	assert_rc 0
	assert_called "plugin install o/a --ref $(sha a) --yes"
	assert_called "plugin disable a.id"
	assert_not_called "plugin action invoke a.id.restart"
}

test_enables() {
	setup_case enables || return 1
	entry a.id o/a "$(sha a)" enable > "${LIST:?}"
	registry "[$(github_plugin a.id o/a "$(sha a)" false)]"
	run_install
	assert_rc 0
	assert_called "plugin enable a.id"
}

test_manual_keeps_state() {
	setup_case manual_keeps_state || return 1
	{
		entry a.id o/a "$(sha a)" manual
		entry b.id o/b "$(sha b)" manual
	} > "${LIST:?}"
	registry "[$(github_plugin a.id o/a "$(sha a)" false),
	    $(github_plugin b.id o/b "$(sha b)" true)]"
	run_install
	assert_rc 0
	assert_no_mutation
}

test_manual_install_invokes() {
	setup_case manual_install || return 1
	entry a.id o/a "$(sha a)" manual restart > "${LIST:?}"
	run_install
	assert_rc 0
	assert_called "plugin install o/a --ref $(sha a) --yes"
	assert_not_called "plugin enable a.id"
	assert_called "plugin action invoke a.id.restart"
}

test_state_without_server() {
	setup_case state_no_server || return 1
	entry a.id o/a "$(sha a)" disable > "${LIST:?}"
	registry "[$(github_plugin a.id o/a "$(sha a)" true)]"
	server_down
	run_install
	assert_rc 0
	assert_not_called "plugin disable a.id"
}

test_install_without_server() {
	setup_case install_no_server || return 1
	entry a.id o/a "$(sha a)" enable restart > "${LIST:?}"
	server_down
	run_install
	assert_rc 0
	assert_called "plugin install o/a --ref $(sha a) --yes"
	assert_not_called "plugin action invoke a.id.restart"
}

test_no_action_column() {
	setup_case no_action || return 1
	entry a.id o/a "$(sha a)" enable > "${LIST:?}"
	run_install
	assert_rc 0
	assert_called "plugin install o/a --ref $(sha a) --yes"
	if grep -q '^plugin action' "${FAKE_HERDR_DIR:?}/calls"; then
		fail "no_action: invoked an action"
	fi
}

test_action_failure() {
	setup_case action_failure || return 1
	entry a.id o/a "$(sha a)" enable restart > "${LIST:?}"
	echo a.id.restart > "${FAKE_HERDR_DIR:?}/fail-action"
	run_install
	assert_rc nonzero
	# Installed at the listed ref, so it is recorded despite the failure.
	assert_state "${LIST:?}"
}

test_install_failure_continues() {
	setup_case install_failure || return 1
	{
		entry a.id o/a "$(sha a)" enable restart
		entry c.id o/c "$(sha c)" enable restart
	} > "${LIST:?}"
	echo o/a > "${FAKE_HERDR_DIR:?}/fail-install"
	run_install
	assert_rc nonzero
	assert_not_called "plugin action invoke a.id.restart"
	assert_called "plugin install o/c --ref $(sha c) --yes"
	assert_called "plugin action invoke c.id.restart"
	# a.id was never installed, so only c.id is recorded.
	entry c.id o/c "$(sha c)" enable restart > "${CASE:?}/expected"
	assert_state "${CASE:?}/expected"
}

test_failed_upgrade_keeps_record() {
	setup_case failed_upgrade || return 1
	entry a.id o/a v2 enable > "${LIST:?}"
	mkdir -p "${STATE%/*}" || return 1
	entry a.id o/a v1 enable > "${STATE:?}"
	cp "${STATE:?}" "${CASE:?}/expected" || return 1
	registry "[$(github_plugin a.id o/a v1)]"
	echo o/a > "${FAKE_HERDR_DIR:?}/fail-install"
	run_install
	assert_rc nonzero
	assert_state "${CASE:?}/expected"
	# Delisted later, the v1 that is really installed is pruned.
	: > "${LIST:?}"
	run_install
	assert_rc 0
	assert_called "plugin uninstall a.id"
}

test_invalid_entry_keeps_record() {
	setup_case invalid_keeps_record || return 1
	entry a.id o/a v2 maybe > "${LIST:?}"
	mkdir -p "${STATE%/*}" || return 1
	entry a.id o/a v1 enable > "${STATE:?}"
	cp "${STATE:?}" "${CASE:?}/expected" || return 1
	registry "[$(github_plugin a.id o/a v1)]"
	run_install
	assert_rc nonzero
	assert_no_mutation
	assert_state "${CASE:?}/expected"
}

test_unreadable_list() {
	setup_case unreadable_list || return 1
	entry a.id o/a v1 enable > "${LIST:?}"
	mkdir -p "${STATE%/*}" || return 1
	entry a.id o/a v1 enable > "${STATE:?}"
	cp "${STATE:?}" "${CASE:?}/expected" || return 1
	registry "[$(github_plugin a.id o/a v1)]"
	chmod 000 "${LIST:?}" || return 1
	run_install
	chmod 644 "${LIST:?}"
	assert_rc nonzero
	assert_no_mutation
	assert_state "${CASE:?}/expected"
}

test_unreadable_record() {
	setup_case unreadable_record || return 1
	: > "${LIST:?}"
	mkdir -p "${STATE%/*}" || return 1
	entry a.id o/a v1 enable > "${STATE:?}"
	registry "[$(github_plugin a.id o/a v1)]"
	chmod 000 "${STATE:?}" || return 1
	run_install
	chmod 644 "${STATE:?}"
	assert_rc nonzero
	assert_no_mutation
}

test_unchanged_record_kept() {
	local _inode="" _stray=""
	setup_case unchanged_record || return 1
	entry a.id o/a v1 enable > "${LIST:?}"
	mkdir -p "${STATE%/*}" || return 1
	cp "${LIST:?}" "${STATE:?}" || return 1
	registry "[$(github_plugin a.id o/a v1)]"
	# shellcheck disable=SC2012 # a fixed path; ls -i is the POSIX way
	_inode="$(ls -i "${STATE:?}" | awk '{print $1}')"
	run_install
	assert_rc 0
	# shellcheck disable=SC2012 # a fixed path; ls -i is the POSIX way
	case "$(ls -i "${STATE:?}" | awk '{print $1}')" in
	"${_inode}") ;;
	*) fail "unchanged_record: rewrote an unchanged record" ;;
	esac
	_stray="$(find "${STATE%/*}" -type f ! -name plugins.list)"
	case "${_stray:+set}" in
	set) fail "unchanged_record: left files: ${_stray}" ;;
	esac
}

test_id_mismatch() {
	setup_case id_mismatch || return 1
	entry wrong.id o/a "$(sha a)" enable restart > "${LIST:?}"
	run_install
	assert_rc nonzero
	assert_not_called "plugin action invoke wrong.id.restart"
}

test_prunes_removed() {
	setup_case prunes_removed || return 1
	entry a.id o/a "$(sha a)" enable > "${LIST:?}"
	mkdir -p "${STATE%/*}" || return 1
	{
		entry a.id o/a "$(sha a)" enable
		entry b.id o/b "$(sha b)" enable
	} > "${STATE:?}"
	registry "[$(github_plugin a.id o/a "$(sha a)"),
	    $(github_plugin b.id o/b "$(sha b)")]"
	run_install
	assert_rc 0
	assert_called "plugin uninstall b.id"
	assert_not_called "plugin uninstall a.id"
	assert_state "${LIST:?}"
}

test_prunes_tag() {
	setup_case prunes_tag || return 1
	: > "${LIST:?}"
	mkdir -p "${STATE%/*}" || return 1
	entry b.id o/b v2 enable > "${STATE:?}"
	registry "[$(github_plugin b.id o/b v2 true "$(sha b)")]"
	run_install
	assert_rc 0
	assert_called "plugin uninstall b.id"
}

test_prune_skips_replaced() {
	setup_case prune_skips_replaced || return 1
	: > "${LIST:?}"
	mkdir -p "${STATE%/*}" || return 1
	{
		entry b.id o/b "$(sha b)" enable
		entry c.id o/c "$(sha c)" enable
	} > "${STATE:?}"
	# b.id was reinstalled by hand at another commit; c.id is now a
	# local link.  Neither is what we installed.
	registry "[$(github_plugin b.id o/b "$(sha d)"), $(local_plugin c.id)]"
	run_install
	assert_rc 0
	assert_no_mutation
	assert_state "${LIST:?}"
}

test_prune_absent_is_noop() {
	setup_case prune_absent || return 1
	: > "${LIST:?}"
	mkdir -p "${STATE%/*}" || return 1
	entry b.id o/b "$(sha b)" enable > "${STATE:?}"
	run_install
	assert_rc 0
	assert_no_mutation
	assert_state "${LIST:?}"
}

test_prune_failure_is_kept() {
	setup_case prune_failure || return 1
	entry a.id o/a "$(sha a)" enable > "${LIST:?}"
	mkdir -p "${STATE%/*}" || return 1
	entry b.id o/b "$(sha b)" enable > "${STATE:?}"
	registry "[$(github_plugin a.id o/a "$(sha a)"),
	    $(github_plugin b.id o/b "$(sha b)")]"
	echo b.id > "${FAKE_HERDR_DIR:?}/fail-uninstall"
	run_install
	assert_rc nonzero
	{
		cat "${LIST:?}"
		entry b.id o/b "$(sha b)" enable
	} > "${CASE:?}/expected"
	assert_state "${CASE:?}/expected"
}

test_list_failure() {
	setup_case list_failure || return 1
	entry a.id o/a "$(sha a)" enable > "${LIST:?}"
	mkdir -p "${STATE%/*}" || return 1
	entry b.id o/b "$(sha b)" enable > "${STATE:?}"
	registry "[$(github_plugin b.id o/b "$(sha b)")]"
	touch "${FAKE_HERDR_DIR:?}/fail-list" || return 1
	run_install
	assert_rc nonzero
	assert_no_mutation
	# a.id cannot be confirmed installed, so only b.id stays recorded.
	entry b.id o/b "$(sha b)" enable > "${CASE:?}/expected"
	assert_state "${CASE:?}/expected"
}

test_missing_list_prunes_all() {
	setup_case missing_list || return 1
	rm -f "${LIST:?}"
	mkdir -p "${STATE%/*}" || return 1
	entry b.id o/b "$(sha b)" enable > "${STATE:?}"
	registry "[$(github_plugin b.id o/b "$(sha b)")]"
	run_install
	assert_rc 0
	assert_called "plugin uninstall b.id"
	: > "${CASE:?}/expected"
	assert_state "${CASE:?}/expected"
}

test_comments_and_blanks() {
	setup_case comments || return 1
	{
		echo "# id${TAB}source${TAB}ref${TAB}state${TAB}action"
		echo
		entry a.id o/a "$(sha a)" enable
	} > "${LIST:?}"
	run_install
	assert_rc 0
	assert_called "plugin install o/a --ref $(sha a) --yes"
	if grep -q '^plugin install #' "${FAKE_HERDR_DIR:?}/calls"; then
		fail "comments: treated a comment as an entry"
	fi
}

test_invalid_entries() {
	setup_case invalid || return 1
	{
		entry b.id o/b "$(sha b)" maybe
		entry 'bad id' o/c "$(sha c)" enable
		entry c.id 'o/c;rm' "$(sha c)" enable
		entry c.id o/c "$(sha c)" enable 're start'
		entry c.id o/c 'v1;rm' enable
		entry c.id o/c -v1 enable
		# A tag and a commit both: the old, two-field layout.
		entry c.id o/c v1 "$(sha c)" enable
		entry c.id o/c "$(sha c)" enable restart
	} > "${LIST:?}"
	run_install
	assert_rc nonzero
	case "$(grep -c '^plugin install' "${FAKE_HERDR_DIR:?}/calls")" in
	1) ;;
	*) fail "invalid: installed an invalid entry: $(tr '\n' ';' \
	    < "${FAKE_HERDR_DIR:?}/calls")" ;;
	esac
	assert_called "plugin install o/c --ref $(sha c) --yes"
}

test_without_herdr() {
	setup_case no_herdr || return 1
	entry a.id o/a "$(sha a)" enable > "${LIST:?}"
	mkdir -p "${CASE:?}/jq-only" || return 1
	ln -s "${JQ_REAL:?}" "${CASE:?}/jq-only/jq" || return 1
	run_install "${CASE:?}/jq-only:${WORK:?}/sys"
	assert_rc 0
	if [ -e "${STATE:?}" ]; then
		fail "no_herdr: recorded an installed list"
	fi
}

test_without_jq() {
	setup_case no_jq || return 1
	entry a.id o/a "$(sha a)" enable > "${LIST:?}"
	rm -f "${BIN:?}/jq" || return 1
	run_install
	assert_rc nonzero
	if [ -s "${FAKE_HERDR_DIR:?}/calls" ]; then
		fail "no_jq: called herdr: $(tr '\n' ';' \
		    < "${FAKE_HERDR_DIR:?}/calls")"
	fi
	if [ -e "${STATE:?}" ]; then
		fail "no_jq: recorded an installed list"
	fi
}

make_sys_path || exit 1

for t in test_installs_missing test_up_to_date_is_noop \
    test_tag_installs test_tag_up_to_date test_reinstalls_other_tag \
    test_commit_matches_unrecorded_ref test_quiet_success \
    test_failure_shows_herdr_output test_prunes_tag \
    test_reinstalls_other_commit test_replaces_local_link \
    test_local_link_without_server test_replaces_other_source \
    test_disables test_disables_after_install test_enables \
    test_manual_keeps_state test_manual_install_invokes \
    test_state_without_server test_install_without_server \
    test_no_action_column test_action_failure \
    test_install_failure_continues test_failed_upgrade_keeps_record \
    test_invalid_entry_keeps_record test_unreadable_list \
    test_unreadable_record test_unchanged_record_kept test_id_mismatch \
    test_prunes_removed test_prune_skips_replaced \
    test_prune_absent_is_noop test_prune_failure_is_kept \
    test_list_failure test_missing_list_prunes_all test_comments_and_blanks \
    test_invalid_entries test_without_herdr test_without_jq; do
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
