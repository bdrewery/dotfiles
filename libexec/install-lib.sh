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
ensure_dir() {
	install -v -m "${2:-0700}" -d "$1"
}

# link_dotfile <src> [dest]
# Symlink ${REPO}/<src> to ~/<dest> using a relative target.
# If dest is omitted, it is derived from the basename of src by stripping
# the "dot." prefix: dot.bashrc -> .bashrc
link_dotfile() {
	local _src="$1" _dest="${2:-}" _base _depth _prefix
	if [ -z "${_dest}" ]; then
		_base="${_src##*/}"
		_dest=".${_base#dot.}"
	fi
	_depth="$(_link_depth "${_dest}")"
	_prefix="$(_link_prefix "${_depth}")"
	ln -nfs "${_prefix}${REPO}/${_src}" "${HOME}/${_dest}"
}

# link_dotdir <src> [dest]
# Like link_dotfile but removes the target first (needed when replacing a
# real directory with a symlink, e.g. ~/.vim, ~/.zsh).
link_dotdir() {
	local _src="$1" _dest="${2:-}"
	if [ -z "${_dest}" ]; then
		_dest=".${_src#dot.}"
	fi
	rm -rf "${HOME}/${_dest}" 2>/dev/null
	link_dotfile "${_src}" "${_dest}"
}

# copy_dotfile <src> <dest>
# Copy (not symlink) ${REPO}/<src> to ~/<dest>.
# Removes a stale symlink at dest first.
copy_dotfile() {
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
		if [ -d "${HOME}/.claude/skills/${_skill_name}" ] && \
		    [ ! -L "${HOME}/.claude/skills/${_skill_name}" ]; then
			rm -rf "${HOME}/.claude/skills/${_skill_name}"
		fi
		ln -nfs "../../${_skill}" "${HOME}/.claude/skills/${_skill_name}"
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
