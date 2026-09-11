#! /bin/sh
#
# Add a fetch-only 'upstream' remote to the submodules that track a personal
# fork, so the fork can be rebased against the project it came from.
#
# Push is aimed at an unusable URL on purpose: these forks carry local
# patches that must never reach the upstream project.
#
# Submodule remotes live in .git/modules/<path>/config, which is not tracked
# content and does not clone, so this has to be run once per checkout rather
# than committed.  Idempotent.
#
# Usage: add-upstream-remotes.sh [repo-root]
#
# Defaults to the checkout this script lives in, not ${PROFILE_REPO}: run
# from a development clone it should act on that clone, not on the deployed
# one.

set -eu

REPO_ROOT="${1:-$(dirname -- "$0")}"

if ! [ -d "${REPO_ROOT}/.git" ]; then
	echo "add-upstream-remotes: not a git checkout: ${REPO_ROOT}" >&2
	exit 1
fi

cd "${REPO_ROOT:?}"

exit_rc=0

# Fed by heredoc rather than a pipe so the loop runs in this shell and
# exit_rc survives it.
while IFS='|' read -r _path _upstream; do
	[ -n "${_path:-}" ] || continue

	if ! git config -f .gitmodules --get "submodule.${_path}.url" >/dev/null 2>&1; then
		echo "${_path}: skipped, not a submodule of this repo" >&2
		exit_rc=1
		continue
	fi

	# A remote can only be added once the submodule has a .git of its own.
	# Test for that directly: `git -C <empty dir> rev-parse` walks up and
	# reports the *parent* repo, which would aim every later git -C in this
	# loop at the superproject.
	if ! [ -e "${_path}/.git" ]; then
		printf '%s: initializing, required before a remote can be added\n' \
		    "${_path}"
		if ! git submodule update --init "${_path}"; then
			echo "${_path}: failed to initialize" >&2
			exit_rc=1
			continue
		fi
	fi

	# Belt and braces: refuse to touch anything that is not this submodule.
	_want="$(cd "${_path}" && pwd -P)"
	_top="$(git -C "${_path}" rev-parse --show-toplevel 2>/dev/null || echo '')"
	if [ "${_top:-}" != "${_want:?}" ]; then
		echo "${_path}: resolves to '${_top:-<none>}', refusing" >&2
		exit_rc=1
		continue
	fi

	if git -C "${_path}" remote get-url upstream >/dev/null 2>&1; then
		git -C "${_path}" remote set-url upstream "${_upstream:?}"
	else
		git -C "${_path}" remote add upstream "${_upstream:?}"
	fi
	git -C "${_path}" remote set-url --push upstream no-push

	printf '%s: upstream %s (fetch), push disabled\n' \
	    "${_path}" "$(git -C "${_path}" remote get-url upstream)"
done <<-EOF
	dot.tmux/plugins/tmux-resurrect|https://github.com/tmux-plugins/tmux-resurrect
	dot.vim/bundle/vim-ollama|https://github.com/gergap/vim-ollama.git
EOF

exit "${exit_rc}"
