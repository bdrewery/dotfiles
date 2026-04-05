#! /bin/sh

D=
while getopts n flag; do
	case "${flag}" in
	n) D=echo ;;
	esac
done

cd ~
REPO=.profile-repo
PROFILE_REPO="${HOME}/${REPO:?}"
export PROFILE_REPO
${D} chmod 0700 "${PROFILE_REPO}"
. "${PROFILE_REPO}/libexec/install-lib.sh"

${D} ensure_dir ~/.generate-tagsd
${D} ensure_dir ~/.screen
${D} ensure_dir ~/.ssh
${D} ensure_dir ~/.claude
${D} ensure_dir ~/.claude/agents
${D} ensure_dir ~/.claude/skills
${D} ensure_dir ~/.vimundo
${D} ensure_dir ~/bin

${D} link_dir dot.vim
${D} chmod 0700 ~/.viminfo > /dev/null 2>&1
${D} link_dir dot.zsh

if [ -z "${D}" ]; then
	if [ -f ~/.ssh/authorized_keys ] && ! [ -d /usr/local/share/system ]; then
		# Don't overwrite it, just ensure all keys are added, and alert
		# on unknown keys
		installed_keys=$(mktemp -t keys.XXXXXXXXXX)
		wanted_keys=$(mktemp -t keys.XXXXXXXXXX)
		sort -u ~/.ssh/authorized_keys | egrep -v '(^$|^#)' > "${installed_keys}"
		sort -u "${PROFILE_REPO:?}/dot.ssh/authorized_keys" | egrep -v '(^$|^#)' > "${wanted_keys}"
		unknown_keys="$(mktemp -ut badkeys.XXXXXXXXX)"
		comm -2 -3 "${installed_keys}" "${wanted_keys}" > "${unknown_keys:?}"
		if [ -s "${unknown_keys:?}" ]; then
			echo "### Unknown SSH Keys" >&2
			cat "${unknown_keys:?}" >&2
		fi
		rm -f "${unknown_keys:?}"
		# Add missing keys
		comm -1 -3 "${installed_keys}" "${wanted_keys}" >> ~/.ssh/authorized_keys
		rm -f "${installed_keys}" "${wanted_keys}"
		chmod 0600 ~/.ssh/authorized_keys
	elif ! [ -f ~/.ssh/authorized_keys ]; then
		install -v -m 0600 "${PROFILE_REPO}/dot.ssh/authorized_keys" ~/.ssh/authorized_keys
	fi
fi

for f in alert-on-exit benv.sh generate-tags generate-tagsd \
    screen-wrapper.sh ssh-wrapper.sh fixscreen make start-screen tf update-profile \
    fping-wait.sh \
    gen-ssh k \
    lscolors lscolors 24-bit-color.sh; do
	if [ -L ~/bin/${f} ]; then
		${D} rm -f ~/bin/${f}
	fi
done
if [ -L ~/.supp ]; then
	${D} rm -f ~/.supp
fi

# Profile files
${D} link_file dot.bash_logout
${D} link_file dot.bash_profile
${D} link_file dot.bashrc
${D} link_file dot.env.common
${D} copy_file dot.login_conf .login_conf # FreeBSD requires not a symlink
${D} link_file dot.logout.common
${D} link_file dot.profile.common
${D} link_file dot.rc.common
${D} link_file dot.zlogout
${D} link_file dot.zprofile
${D} link_file dot.zshenv
${D} link_file dot.zshrc
# Misc
${D} link_file dot.ctags
${D} link_file dot.git-prompt.conf
${D} link_file dot.gitconfig
${D} link_file dot.gitignore
${D} link_file dot.inputrc
${D} link_file dot.lessfilter
${D} link_file dot.nanorc
${D} link_file dot.screenrc
${D} link_file dot.shellcheckrc
${D} link_file dot.tmux.conf
${D} link_file dot.valgrindrc
${D} link_file dot.vimrc
${D} link_file dot.claude/statusline-command.sh
${D} install_claude_skills
${D} sync_dir dot.config .config
${D} mkdir -p ~/.tmux/plugins
${D} link_file dot.tmux/plugins/tpm
${D} link_file dot.zpool.d

# Process private/local dotfile repos listed in ~/.local.profile-repo
if [ -f ~/.local.profile-repo ]; then
	${D} install -v -m 0700 -d "${PROFILE_REPO}/local.d"
	while read -r _repo_url; do
		case "${_repo_url}" in
		""|\#*) continue ;;
		esac
		_repo_name="${_repo_url##*/}"
		_repo_name="${_repo_name%.git}"
		_repo_dir="${REPO:?}/local.d/${_repo_name}"
		if [ -z "${D}" ]; then
			if [ -d "${_repo_dir}/.git" ]; then
				echo "Updating local repo: ${_repo_name}"
				git -C "${_repo_dir}" fetch origin --depth=1
				git -C "${_repo_dir}" reset --hard origin/HEAD
			else
				echo "Cloning local repo: ${_repo_name}"
				git clone --depth=1 "${_repo_url}" "${_repo_dir}"
			fi
		fi
		if [ -r "${_repo_dir}/install.sh" ]; then
			echo "==> Running ${_repo_name}/install.sh"
			REPO="${_repo_dir}" sh "${_repo_dir}/install.sh" ${D:+-n}
		fi
	done < ~/.local.profile-repo
fi

if [ -z "${D}" ] && which npm >/dev/null 2>&1 && [ "$(id -u)" != "0" ]; then
	mkdir -p ~/.npm-global
	# npm gets confused if HOME contains symlinks and complains about
	# not being able to change the config.
	npm() {
		local HOME="${HOME}"
		export HOME="$(realpath "${HOME}")"
		command npm "$@"
	}
	case "$(npm config get prefix)" in
	undefined)
		npm config get prefix
		npm config set prefix ~/.npm-global
		;;
	esac
fi
