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
# No-op if the symlink already points to the correct target.
link_file() {
	local _src="$1" _dest="${2:-}" _depth _prefix _target _mode
	preserve_as_local "${_src}"
	if [ -z "${_dest}" ]; then
		_dest=".${_src#dot.}"
	fi
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
# <dest>.profile-repo-replaced rather than deleted.
# No-op if the symlink already points to the correct target.
link_dir() {
	local _src="$1" _dest="${2:-}"
	# preserve_as_local "${_src}"
	if [ -z "${_dest}" ]; then
		_dest=".${_src#dot.}"
	fi
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
# If ~/<file> is a regular file (not a symlink) and ~/<file>.local does not
# exist, rename it to ~/<file>.local before symlinking over it.
preserve_as_local() {
	local _src="$1"
	local _file=".${_src#dot.}"
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
