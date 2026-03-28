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
	local _src="$1" _dest="${2:-}" _depth _prefix _target
	if [ -z "${_dest}" ]; then
		_dest=".${_src#dot.}"
	fi
	_depth="$(_link_depth "${_dest}")"
	_prefix="$(_link_prefix "${_depth}")"
	_target="${_prefix}${REPO}/${_src}"
	if [ "$(readlink "${HOME}/${_dest}")" = "${_target}" ]; then
		return
	fi
	ln -nfs "${_target}" "${HOME}/${_dest}"
}

# link_dir <src> [dest]
# Like link_file but handles an existing target that is a real directory
# or a symlink not owned by this repo.  Displaced targets are moved to
# <dest>.profile-repo-replaced rather than deleted.
# No-op if the symlink already points to the correct target.
link_dir() {
	local _src="$1" _dest="${2:-}"
	if [ -z "${_dest}" ]; then
		_dest=".${_src#dot.}"
	fi
	if [ -L "${HOME}/${_dest}" ]; then
		case "$(readlink "${HOME}/${_dest}")" in
		*"${REPO}/"*) ;; # ours — link_file handles idempotently
		*)
			mv "${HOME}/${_dest}" "${HOME}/${_dest}.profile-repo-replaced"
			;;
		esac
	elif [ -e "${HOME}/${_dest}" ]; then
		mv "${HOME}/${_dest}" "${HOME}/${_dest}.profile-repo-replaced"
	fi
	link_file "${_src}" "${_dest}"
}

# copy_file <src> <dest>
# Copy (not symlink) ${REPO}/<src> to ~/<dest>.
# Removes a stale symlink at dest first.
copy_file() {
	local _src="$1" _dest="$2"
	[ -L "${HOME}/${_dest}" ] && rm -f "${HOME}/${_dest}"
	install -C -v "${REPO}/${_src}" "${HOME}/${_dest}"
}

# sync_dir <src> <dest>
# rsync ${REPO}/<src>/ into ~/<dest>/.
sync_dir() {
	local _src="$1" _dest="$2"
	rsync -avH "${REPO}/${_src}/" "${HOME}/${_dest}/"
}

# preserve_as_local <file>
# If ~/<file> is a regular file (not a symlink) and ~/<file>.local does not
# exist, rename it to ~/<file>.local before symlinking over it.
preserve_as_local() {
	local _file="$1"
	if [ -f "${HOME}/${_file}" ] && [ ! -L "${HOME}/${_file}" ] && \
	    [ ! -L "${HOME}/${_file}.local" ] && \
	    [ ! -f "${HOME}/${_file}.local" ]; then
		mv "${HOME}/${_file}" "${HOME}/${_file}.local"
	fi
}

# install_claude_skills [skills_dir]
# Install all skills from ${REPO}/<skills_dir> into ~/.claude/skills/.
# Removes stale skills that were previously installed from this REPO.
# Default skills_dir: dot.claude/skills
install_claude_skills() {
	local _skills_dir="${1:-dot.claude/skills}"
	local _skill _skill_name _linkdest

	for _skill in "${REPO}/${_skills_dir}/"*; do
		case "${_skill}" in
		"${REPO}/${_skills_dir}/*") continue ;;
		esac
		_skill_name="${_skill##*/}"
		link_dir "${_skills_dir}/${_skill_name}"
	done

	# Remove skills owned by this REPO that no longer exist in source
	for _skill in "${HOME}/.claude/skills/"*; do
		case "${_skill}" in
		"${HOME}/.claude/skills/*") continue ;;
		esac
		[ ! -L "${_skill}" ] && continue
		_linkdest="$(readlink "${_skill}")"
		case "${_linkdest}" in
		"../../${REPO}/${_skills_dir}/"*) ;;
		*) continue ;;
		esac
		if [ ! -r "${_skill}" ]; then
			echo "Removing stale skill: ${_skill##*/}"
			rm -f "${_skill}"
		fi
	done
}
