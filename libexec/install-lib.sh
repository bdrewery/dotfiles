#! /bin/sh
# Shared install helpers for dotfile repos.
#
# Callers must:
#   - cd "${HOME}" before sourcing (top-level install.sh does this)
#   - set REPO to the repo path relative to HOME (e.g. .profile-repo)
#
# Sub-repos sourced by the top-level install.sh inherit both CWD and REPO
# from the environment; they should not set REPO or cd themselves.

# _link_depth <home-relative-path>
# Count directory components in path (number of / separators).
# .bashrc -> 0, .claude/CLAUDE.md -> 1, .tmux/plugins/tpm -> 2
_link_depth() {
	local _path="$1" _depth=0 _p
	_p="${_path}"
	while case "${_p}" in */*) true ;; *) false ;; esac; do
		_depth=$((_depth + 1))
		_p="${_p#*/}"
	done
	printf '%d' "${_depth}"
}

# _link_prefix <depth>
# Return ../ repeated <depth> times.
_link_prefix() {
	local _depth="$1" _prefix="" _i=0
	while [ "${_i}" -lt "${_depth}" ]; do
		_prefix="../${_prefix}"
		_i=$((_i + 1))
	done
	printf '%s' "${_prefix}"
}

_replace() {
	local _file="${1:?}"
	case "${_file:?}" in
	"${HOME}"/*) ;;
	*)
		echo "_replace: Invalid param: ${_file}" >&2
		return 1
		;;
	esac
	mv -v "${_file:?}" \
	    "${_file:?}.profile-repo-$(date +"%Y%m%dT%H%M%S")"
}

# ensure_dir <path> [mode]
# Create directory with permissions (default 0700).
# No-op if the directory already exists with the correct mode.
ensure_dir() {
	local _mode="${2:-0700}"
	if [ -d "$1" ] && [ -n "$(find "$1" -prune -perm "${_mode}" -print)" ]; then
		return
	fi
	install -v -m "${_mode}" -d "$1"
}

# link_file <src> [dest]
# Symlink ${REPO}/<src> to ~/<dest> using a relative target.
# If dest is omitted, it is derived from the basename of src by stripping
# the "dot." prefix: dot.bashrc -> .bashrc
# A regular file already at ~/<dest> is kept by preserve_as_local; a
# symlink there is replaced.
# No-op if the symlink already points to the correct target.
link_file() {
	local _src="$1" _dest="${2:-}" _depth _prefix _target _mode
	if [ -z "${_dest}" ]; then
		_dest=".${_src#dot.}"
	fi
	preserve_as_local "${_dest:?}"
	_depth="$(_link_depth "${_dest:?}")"
	_prefix="$(_link_prefix "${_depth:?}")"
	_target="${_prefix}${REPO:?}/${_src:?}"
	case "$(readlink "${HOME}/${_dest}")" in
	"${_target}") ;;
	*)
		ln -nfs "${_target:?}" "${HOME:?}/${_dest:?}"
		;;
	esac
	if [ -d "${HOME}/${_dest}" ]; then
		_mode="og-w,u+w"
	else
		_mode="a-w"
	fi
	chmod "${_mode}" "${HOME}/${_dest}"
}

# link_dir <src> [dest]
# Like link_file but handles an existing target that is a real directory
# or a symlink not owned by this repo.  Displaced targets are moved to
# <dest>.profile-repo-YYYYMMDDTHHMMSS by _replace rather than deleted.
# No-op if the symlink already points to the correct target.
link_dir() {
	local _src="$1" _dest="${2:-}"
	if [ -z "${_dest}" ]; then
		_dest=".${_src#dot.}"
	fi
	# preserve_as_local "${_dest:?}"
	if [ -L "${HOME}/${_dest}" ]; then
		case "$(readlink "${HOME}/${_dest}")" in
		*"${REPO:?}/"*) ;; # ours — link_file handles idempotently
		*)
			_replace "${HOME:?}/${_dest:?}"
			;;
		esac
	elif [ -e "${HOME:?}/${_dest:?}" ]; then
		_replace "${HOME:?}/${_dest:?}"
	fi
	link_file "${_src:?}" "${_dest:?}"
}

# copy_file <src> <dest>
# Copy (not symlink) ${REPO}/<src> to ~/<dest>.
# Removes a stale symlink at dest first.
copy_file() {
	local _src="$1" _dest="$2"
	[ -L "${HOME:?}/${_dest:?}" ] && rm -fv "${HOME:?}/${_dest:?}"
	# preserving this file would be too complex
	install -C -v -m 0400 "${REPO:?}/${_src}" "${HOME}/${_dest}"
}

# sync_dir <src> <dest>
# rsync ${REPO}/<src>/ into ~/<dest>/.
sync_dir() {
	local _src="$1" _dest="$2"
	rsync -avH "${REPO:?}/${_src:?}/" "${HOME:?}/${_dest:?}/"
}

# preserve_as_local <file>
# <file> is relative to HOME (e.g. .bashrc, .claude/CLAUDE.md).
# If ~/<file> is a regular file (not a symlink) and ~/<file>.local does not
# exist, rename it to ~/<file>.local before symlinking over it; otherwise
# move it aside with _replace.
preserve_as_local() {
	local _file="${1:?}"
	if [ -f "${HOME}/${_file}" ] && [ ! -L "${HOME}/${_file}" ]; then
		if [ ! -L "${HOME}/${_file}.local" ] &&
		    [ ! -f "${HOME}/${_file}.local" ]; then
			mv -v "${HOME:?}/${_file:?}" "${HOME:?}/${_file:?}.local"
		else
			_replace "${HOME:?}/${_file:?}"
		fi
	fi
}

# install_claude_skills
# Install all skills/agents from ${REPO}/<type_dir> into ~/.claude/(skills|agent)/.
# Removes stale skills that were previously installed from this REPO.
install_claude_skills() {
	_install_claude_skills skills
	_install_claude_skills agents
}
_install_claude_skills() {
	local _skills_type="${1:?}"
	local _skills_dir="dot.claude/${_skills_type}"
	local _skill _skill_name _linkdest

	for _skill in "${REPO:?}/${_skills_dir}/"*; do
		case "${_skill}" in
		"${REPO:?}/${_skills_dir}/*") continue ;;
		esac
		_skill_name="${_skill##*/}"
		link_dir "${_skills_dir:?}/${_skill_name:?}"
	done

	# Remove skills owned by this REPO that no longer exist in source
	for _skill in "${HOME}/.claude/${_skills_type}/"*; do
		case "${_skill}" in
		"${HOME}/.claude/${_skills_type}/*") continue ;;
		esac
		[ ! -L "${_skill}" ] && continue
		_linkdest="$(readlink "${_skill}")"
		case "${_linkdest}" in
		*"/${REPO:?}/${_skills_dir}/"*) ;;
		*) continue ;;
		esac
		if [ ! -r "${_skill}" ]; then
			echo "Removing stale skill: ${_skill##*/}"
			rm -f "${_skill:?}"
		fi
	done
}

# herdr_reload_config
# Reload a running herdr server's config and summarize the JSON result;
# a running server does not watch config.toml for changes.
# Requires jq. No-op if herdr is not installed or its server is not running.
# Depends on: herdr_server_running, herdr, jq.
herdr_reload_config() {
	local _out=

	command -v herdr >/dev/null 2>&1 || return 0
	if ! command -v jq >/dev/null 2>&1; then
		echo "Skipping herdr_reload_config: need jq" >&2
		return 1
	fi
	herdr_server_running || return 0
	if ! _out="$(herdr server reload-config)"; then
		printf '%s\n' "${_out}" >&2
		echo "==> herdr: server reload-config failed" >&2
		return 0
	fi
	printf '%s\n' "${_out}" | jq -r '"herdr: \(.id): \(.result.status)",
	    (.result.diagnostics[]? |
	    "herdr: diagnostic: \(if type == "string" then . else tojson end)")'
}

# herdr_server_running
# Succeed if a herdr server is running.  Enabling, disabling, unlinking
# and invoking plugin actions need one; install and uninstall do not.
# Depends on: herdr, jq.
herdr_server_running() {
	herdr status server --json </dev/null 2>/dev/null |
	    jq -e '.running == true' >/dev/null 2>&1
}

# herdr_plugin_state <plugin_id>
# Print "<kind>\t<owner/repo>\t<requested_ref>\t<commit>\t<enabled>" for
# the registered herdr plugin <plugin_id>, or nothing if it is not
# registered.  Fields that do not apply to a plugin are "-".
# Depends on: herdr, jq.
herdr_plugin_state() {
	local _id="${1:?}" _json=""

	_json="$(herdr plugin list --json </dev/null)" || {
		echo "herdr_plugin_state: herdr plugin list failed" >&2
		return 1
	}
	printf '%s\n' "${_json}" | jq -r --arg id "${_id}" '
		.result.plugins[] | select(.plugin_id == $id) |
		[.source.kind,
		 (if .source.kind == "github"
		  then "\(.source.owner)/\(.source.repo)" else "-" end),
		 (.source.requested_ref // "-"),
		 (.source.resolved_commit // "-"),
		 .enabled] | @tsv'
}

# _herdr_plugin_is <state-line> <owner/repo> <ref>
# Succeed if herdr_plugin_state output <state-line> is a GitHub install
# of <owner/repo> at <ref>: installed from <ref>, or, for installs that
# predate herdr recording the ref, resolved to <ref> as a commit.
_herdr_plugin_is() {
	local _src="$2" _ref="$3" _tab="" _kind="" _have_src="" _req=""
	local _commit="" _enabled=""

	_tab="$(printf '\t')"
	IFS="${_tab}" read -r _kind _have_src _req _commit _enabled <<-EOF
		${1}
	EOF
	case "${_kind}:${_have_src}" in
	"github:${_src}") ;;
	*) return 1 ;;
	esac
	case "${_ref}" in
	"${_req}"|"${_commit}") return 0 ;;
	esac
	return 1
}

# _herdr_plugin_entry_valid <id> <source> <ref> <state> <action> <extra>
# Succeed if the fields form a valid plugins.list entry.  Otherwise print
# why to stderr and fail.  Nothing may start with "-", so no field can be
# taken as a herdr option.
_herdr_plugin_entry_valid() {
	local _id="$1" _src="$2" _ref="$3" _state="$4" _action="$5"
	local _extra="$6" _src_ok=0

	case "${_id}" in
	""|-*|*[!A-Za-z0-9._-]*)
		echo "invalid plugin id '${_id}'" >&2
		return 1
		;;
	esac
	case "${_src}" in
	-*|*/*/*|*[!A-Za-z0-9._/-]*|/*|*/|*/-*) ;;
	*/*) _src_ok=1 ;;
	esac
	case "${_src_ok}" in
	0)
		echo "${_id}: invalid source '${_src}';" \
		    "expected <owner>/<repo>" >&2
		return 1
		;;
	esac
	case "${_ref}" in
	""|-*|*[!A-Za-z0-9._/-]*)
		echo "${_id}: invalid ref '${_ref}'" >&2
		return 1
		;;
	esac
	case "${_state}" in
	enable|disable|manual) ;;
	*)
		echo "${_id}: invalid state '${_state}'" >&2
		return 1
		;;
	esac
	case "${_action}" in
	-*|*[!A-Za-z0-9._-]*)
		echo "${_id}: invalid action '${_action}'" >&2
		return 1
		;;
	esac
	case "${_extra:+set}" in
	set)
		echo "${_id}: unexpected fields '${_extra}'" >&2
		return 1
		;;
	esac
}

# _herdr_run <caller> <herdr-args...>
# Run herdr <herdr-args...> with stdin from /dev/null, keeping its output
# unless it fails; then print it to stderr after saying which call failed.
# Depends on: herdr.
_herdr_run() {
	local _caller="${1:?}" _out=""
	shift

	if _out="$(herdr "$@" </dev/null 2>&1)"; then
		return 0
	fi
	echo "${_caller}: herdr $* failed:" >&2
	printf '%s\n' "${_out}" >&2
	return 1
}

# _herdr_sync_plugin <id> <owner/repo> <ref> <state> <action> <server>
# Bring herdr plugin <id> to one plugins.list entry.  Unless <id> is
# already a GitHub install of <owner/repo> at <ref> it is installed from
# there, unlinking a local link of the same id first.  The state is then
# applied (manual leaves it to the host), and <action>, if not empty, is
# invoked after an install if the plugin is enabled.  <server> is 1 if a
# herdr server is running.
# Returns, having said why on failure:
#   0  done
#   1  installed at <ref>, but applying the state or <action> failed
#   2  not installed at <ref>
# Depends on: herdr_plugin_state, _herdr_plugin_is, _herdr_run, herdr, jq.
_herdr_sync_plugin() {
	local _id="$1" _src="$2" _ref="$3" _state="$4" _action="$5"
	local _server="$6" _tab="" _line="" _enabled="" _installed=0 _rc=0

	_tab="$(printf '\t')"
	_line="$(herdr_plugin_state "${_id}")" || return 2
	if ! _herdr_plugin_is "${_line}" "${_src}" "${_ref}"; then
		case "${_line}:${_server}" in
		local*:1)
			echo "=> Unlinking herdr plugin: ${_id}"
			_herdr_run _herdr_sync_plugin plugin unlink "${_id}" ||
			    return 2
			;;
		local*)
			echo "_herdr_sync_plugin: herdr server not running;" \
			    "${_id} stays linked" >&2
			return 2
			;;
		esac
		echo "=> Installing herdr plugin: ${_id} (${_src} ${_ref})"
		_herdr_run _herdr_sync_plugin plugin install "${_src}" \
		    --ref "${_ref}" --yes || return 2
		_installed=1
		_line="$(herdr_plugin_state "${_id}")" || return 2
		if ! _herdr_plugin_is "${_line}" "${_src}" "${_ref}"; then
			echo "_herdr_sync_plugin: ${_id} is not registered" \
			    "after installing ${_src}; is the id right?" >&2
			return 2
		fi
	fi
	_enabled="${_line##*"${_tab}"}"
	case "${_state}:${_enabled}" in
	enable:false|disable:true)
		case "${_server}" in
		1)
			echo "=> Setting herdr plugin ${_state}: ${_id}"
			if _herdr_run _herdr_sync_plugin plugin "${_state}" \
			    "${_id}"; then
				_enabled="$([ "${_state}" = enable ] &&
				    echo true || echo false)"
			else
				_rc=1
			fi
			;;
		*)
			echo "herdr server not running; ${_id} is not" \
			    "yet ${_state}d"
			;;
		esac
		;;
	esac
	case "${_installed}:${_action:+set}:${_enabled}:${_server}" in
	1:set:true:1)
		echo "=> Invoking herdr plugin action: ${_id}.${_action}"
		_herdr_run _herdr_sync_plugin plugin action invoke \
		    "${_id}.${_action}" || _rc=1
		;;
	esac
	return "${_rc}"
}

# _herdr_prune_plugin <id> <owner/repo> <ref>
# Uninstall herdr plugin <id> if it is still the GitHub install of
# <owner/repo> at <ref> that a previous run made; otherwise it has been
# replaced since and is left alone.
# Depends on: herdr_plugin_state, _herdr_plugin_is, _herdr_run, herdr, jq.
_herdr_prune_plugin() {
	local _id="$1" _src="$2" _ref="$3" _line=""

	_line="$(herdr_plugin_state "${_id}")" || return 1
	_herdr_plugin_is "${_line}" "${_src}" "${_ref}" || return 0
	echo "=> Uninstalling herdr plugin: ${_id}"
	_herdr_run _herdr_prune_plugin plugin uninstall "${_id}"
}

# _herdr_recorded_line <file> <id>
# Print the entry for <id> in the recorded list <file>, if any.
_herdr_recorded_line() {
	[ -f "${1:?}" ] || return 0
	awk -F "$(printf '\t')" -v id="${2:?}" \
	    '$1 == id {print; exit}' "${1:?}"
}

# install_herdr_plugins
# Sync herdr plugins with ${REPO}/dot.config/herdr/plugins.list, one
# tab-separated entry per line ("#" starts a comment):
#   <plugin_id> <owner/repo> <ref> <state> [action]
# <ref> is a tag or full commit hash to install.  herdr records it, and
# a plugin is reinstalled only when it changes, so a tag moved upstream
# is not followed.
# <state> is applied on every run:
#   enable|disable  enable or disable the plugin
#   manual          install only; the host owns the state
# [action] is invoked after the plugin is (re)installed, for plugins
# whose running processes must pick up the new code.
# What is installed is recorded in ${REPO}/.state/herdr-plugins.list,
# which git ignores: the listed entry once a plugin is at its <ref>,
# else its previous record.  Recorded plugins no longer listed are uninstalled;
# any whose uninstall fails stay recorded, to retry.
# Returns non-zero if any plugin failed to sync.
# Depends on: _herdr_sync_plugin, _herdr_prune_plugin,
#     _herdr_recorded_line, herdr, jq.
install_herdr_plugins() {
	local _list="" _dir="" _recorded="" _tmp="" _record="" _want=""
	local _tab="" _nl="" _line="" _sync_rc=0
	local _id="" _src="" _ref="" _state="" _action="" _extra=""
	local _server=0 _rc=0

	_nl='
'

	if ! command -v herdr >/dev/null 2>&1; then
		echo "Skipping install_herdr_plugins: herdr not installed"
		return 0
	fi
	if ! command -v jq >/dev/null 2>&1; then
		echo "Skipping install_herdr_plugins: need jq" >&2
		return 1
	fi
	_list="${REPO:?}/dot.config/herdr/plugins.list"
	_dir="${REPO:?}/.state"
	_recorded="${_dir}/herdr-plugins.list"
	_tab="$(printf '\t')"
	for _line in "${_list}" "${_recorded}"; do
		if [ -e "${_line}" ] && [ ! -r "${_line}" ]; then
			echo "install_herdr_plugins: cannot read ${_line}" >&2
			return 1
		fi
	done
	if [ -f "${_list}" ]; then
		_want="$(awk -F "${_tab}" '$1 !~ /^#/ && NF {print $1}' \
		    "${_list}")" || {
			echo "install_herdr_plugins: cannot read ${_list}" >&2
			return 1
		}
	fi
	if herdr_server_running; then
		_server=1
	fi
	if [ -f "${_list}" ]; then
		while IFS="${_tab}" read -r _id _src _ref _state _action \
		    _extra; do
			case "${_id}" in
			"#"*|"") continue ;;
			esac
			_sync_rc=2
			if _herdr_plugin_entry_valid "${_id}" "${_src}" \
			    "${_ref}" "${_state}" "${_action}" "${_extra}"; then
				_herdr_sync_plugin "${_id}" "${_src}" "${_ref}" \
				    "${_state}" "${_action}" "${_server}"
				_sync_rc=$?
			else
				echo "install_herdr_plugins: skipping invalid" \
				    "entry in ${_list}" >&2
			fi
			case "${_sync_rc}" in
			0|1)
				_line="$(printf '%s\t%s\t%s\t%s%s' "${_id}" \
				    "${_src}" "${_ref}" "${_state}" \
				    "${_action:+${_tab}${_action}}")"
				;;
			*)
				_line="$(_herdr_recorded_line "${_recorded}" \
				    "${_id}")" || return 1
				;;
			esac
			case "${_sync_rc}" in
			0) ;;
			*) _rc=1 ;;
			esac
			_record="${_record}${_line:+${_line}${_nl}}"
		done < "${_list}"
	fi
	if [ -f "${_recorded}" ]; then
		while IFS="${_tab}" read -r _id _src _ref _state _action \
		    _extra; do
			case "${_id}" in
			"#"*|"") continue ;;
			esac
			case "${_nl}${_want}${_nl}" in
			*"${_nl}${_id}${_nl}"*) continue ;;
			esac
			_herdr_plugin_entry_valid "${_id}" "${_src}" \
			    "${_ref}" "${_state}" "${_action}" "${_extra}" \
			    2>/dev/null || continue
			if ! _herdr_prune_plugin "${_id}" "${_src}" "${_ref}"
			then
				_rc=1
				_record="${_record}$(printf '%s\t%s\t%s\t%s%s' \
				    "${_id}" "${_src}" "${_ref}" "${_state}" \
				    "${_action:+${_tab}${_action}}")${_nl}"
			fi
		done < "${_recorded}"
	fi
	ensure_dir "${_dir}" || return 1
	_tmp="$(mktemp "${_dir}/.herdr-plugins.list.XXXXXX")" || return 1
	if ! printf '%s' "${_record}" > "${_tmp}"; then
		echo "install_herdr_plugins: writing ${_tmp} failed" >&2
		rm -f "${_tmp}"
		return 1
	fi
	if cmp -s "${_tmp}" "${_recorded}"; then
		rm -f "${_tmp}"
	elif ! mv -f "${_tmp}" "${_recorded}"; then
		echo "install_herdr_plugins: failed to record ${_recorded}" >&2
		rm -f "${_tmp}"
		return 1
	fi
	return "${_rc}"
}

# bootstrap and sync a vim python venv
setup_venv() {
	local _src="$1" _dest _venv _req _reqin _sync_req
	local PIP_NO_COLOR PIP_PROGRESS_BAR
	local _need_venv

	_need_venv=0
	export PIP_NO_COLOR=1
	export PIP_PROGRESS_BAR=off

	_dest=".${_src#dot.}"
	_venv="${HOME}/${_dest}"
	_reqin="${_venv}-requirements.txt"
	_req="${_venv}-requirements.txt.compiled"
	if [ ! -f "${_venv}/pyvenv.cfg" -o ! -x "${_venv}/bin/pip" ]; then
		_need_venv=1
	elif [ -x "${_venv}/bin/pip" ] &&
	    ! "${_venv}/bin/pip" --version >/dev/null 2>&1; then
		# Major version upgrade probably
		echo "setup_venv [${_src}]: Must reinstall for upgrade" >&2
		${D} rm -rf "${_venv}"
		${D} rm -rf "${_req}"
		_need_venv=1
	fi
	if [ "${_need_venv}" -eq 1 ] ;then
		echo "setup_venv [${_src}]: Setting up" >&2
		${D} python3 -m venv "${_venv}"
	fi
	# pip-tools reaches into pip's private API, so upgrading pip on every run
	# while pip-tools stays at whatever first got installed drifts them into
	# an ImportError.  They have to move together.  pip-sync below cannot do
	# this itself: it is handed pip-tools unpinned, and any installed version
	# already satisfies that.
	${D} "${_venv}/bin/pip" install --upgrade pip pip-tools
	if [ ! -x "${_venv}/bin/pip-sync" ]; then
		echo "setup_venv [${_src}]: Failed to install pip-sync" >&2
		return 1
	fi
	if [ -f "${_reqin}" ] && [ ! -f "${_req}" -o "${_reqin}" -nt "${_req}" ]; then
		echo "setup_venv [${_src}]: Compiling requirements" >&2
		${D} "${_venv}/bin/pip-compile" --no-color --quiet --output-file="${_req}" "${_reqin}"
	fi
	_sync_req=
	[ -f "${_req}" ] && _sync_req="${_req}"
	echo "setup_venv [${_src}]: Syncing" >&2
	${D} "${_venv}/bin/pip-sync" /dev/stdin ${_sync_req:+"${_sync_req}"} <<-EOF
		pip-tools
	EOF
}

# git_follows_remote_head
# True if git can update refs/remotes/<remote>/HEAD from the remote during
# a fetch (remote.<name>.followRemoteHEAD, git 2.48+).
# Part of git_update: a behavior change here must bump GIT_UPDATE_REVISION.
git_follows_remote_head() {
	local _v _major _minor
	_v="$(git version)" || return
	_v="${_v#git version }"
	_major="${_v%%.*}"
	_v="${_v#*.}"
	_minor="${_v%%.*}"
	case "${_major:-x}${_minor:-x}" in
	*[!0-9]*) return 1 ;;
	esac
	[ "${_major}" -gt 2 ] ||
	    { [ "${_major}" -eq 2 ] && [ "${_minor}" -ge 48 ]; }
}

# git_fetch_origin <repo_dir>
# Fetch every branch of origin into the shallow clone at <repo_dir> and
# point origin/HEAD at the remote's default branch: during the fetch where
# git supports it, otherwise with a separate "remote set-head" query.
# Part of git_update: a behavior change here must bump GIT_UPDATE_REVISION.
git_fetch_origin() {
	local _dir="${1:?repo_dir}" _followhead=
	if git_follows_remote_head; then
		_followhead="remote.origin.followRemoteHEAD=always"
	fi
	git -C "${_dir}" ${_followhead:+-c "${_followhead}"} fetch --quiet \
	    --prune --no-recurse-submodules origin --depth=1 || return
	case "${_followhead:+set}" in
	set) ;;
	*) git -C "${_dir}" remote set-head origin --auto >/dev/null ;;
	esac
}

# Revision of git_update.  Bump it with any behavior change to git_update or
# the helpers it calls (git_fetch_origin, git_follows_remote_head); comment
# or formatting changes need no bump.  update.sh runs the git_update that
# was installed before it fetched, and install.sh runs git_update again when
# that one's revision, as recorded in PROFILE_GIT_UPDATE_REVISION, differs
# from this one.  So a bump makes the change take effect in the same
# update-profile run rather than the next one.
GIT_UPDATE_REVISION=2

# git_update <repo_name> <repo_dir>
# Reset the clone at <repo_dir> to a shallow copy of origin's default
# branch, discarding local changes.  origin/HEAD is re-read from the remote
# each time (see git_fetch_origin) so a renamed default branch (e.g.
# master -> main) is followed, with the local branch of the same name
# checked out and tracking it; other local branches are deleted.  A failed
# fetch, such as on an offline host, is reported and leaves the checkout as
# it is; a failed submodule update is reported too.  Any other failure
# returns non-zero.
# Exports PROFILE_GIT_UPDATE_REVISION set to GIT_UPDATE_REVISION on entry, so
# install.sh can tell which revision ran even if it only reported a failed
# fetch.
git_update() {
	local _repo_name="${1:?repo_name}"
	local _repo_dir="${2:?repo_dir}"
	local _branch _ref _refs
	# A behavior change in this function or its helpers must bump
	# GIT_UPDATE_REVISION; see there.
	PROFILE_GIT_UPDATE_REVISION="${GIT_UPDATE_REVISION:?}"
	export PROFILE_GIT_UPDATE_REVISION
	echo "==> ${_repo_name:?}: Fetching"
	git -C "${_repo_dir:?}" remote set-branches origin '*' || return
	if ! git_fetch_origin "${_repo_dir:?}"; then
		echo "==> ${_repo_name:?}: Fetch failed;" \
		    "keeping the current checkout" >&2
		return 0
	fi
	_branch="$(git -C "${_repo_dir:?}" symbolic-ref \
	    refs/remotes/origin/HEAD)" || return
	_branch="${_branch#refs/remotes/origin/}"
	git -C "${_repo_dir:?}" reset --hard refs/remotes/origin/HEAD || return
	git -C "${_repo_dir:?}" checkout --quiet --track \
	    -B "${_branch:?}" "refs/remotes/origin/${_branch:?}" || return
	_refs="$(git -C "${_repo_dir:?}" for-each-ref --format='%(refname)' \
	    refs/heads)" || return
	for _ref in ${_refs}; do
		case "${_ref}" in
		"refs/heads/${_branch:?}") ;;
		*)
			git -C "${_repo_dir:?}" branch --quiet -D -- \
			    "${_ref#refs/heads/}" || return
			;;
		esac
	done
	echo "==> ${_repo_name:?}: Updating submodules"
	if ! git -C "${_repo_dir:?}" submodule --quiet update --init \
	    --depth=1; then
		echo "==> ${_repo_name:?}: Submodule update failed;" \
		    "continuing" >&2
	fi
	git -C "${_repo_dir:?}" reflog expire --expire-unreachable=all --all ||
	    return
	git -C "${_repo_dir:?}" gc --quiet --prune=all || return
}
