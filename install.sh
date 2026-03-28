#! /bin/sh

cd ~
REPO=.profile-repo
REPO_DIR="${HOME}/${REPO}"
export REPO_DIR
chmod 0700 "${REPO}"
. "${REPO}/libexec/install-lib.sh"

ensure_dir ~/.generate-tagsd
ensure_dir ~/.screen
ensure_dir ~/.ssh
ensure_dir ~/.claude
ensure_dir ~/.claude/skills
ensure_dir ~/.vimundo
ensure_dir ~/bin

link_dotdir dot.vim
chmod 0700 ~/.viminfo > /dev/null 2>&1
link_dotdir dot.zsh

if [ -f ~/.ssh/authorized_keys ] && ! [ -d /usr/local/share/system ]; then
	# Don't overwrite it, just ensure all keys are added, and alert
	# on unknown keys
	installed_keys=$(mktemp -t keys.XXXXXXXXXX)
	wanted_keys=$(mktemp -t keys.XXXXXXXXXX)
	sort -u ~/.ssh/authorized_keys | egrep -v '(^$|^#)' > "${installed_keys}"
	sort -u "${REPO}/dot.ssh/authorized_keys" | egrep -v '(^$|^#)' > "${wanted_keys}"
	echo "### Unknown SSH Keys" >&2
	comm -2 -3 "${installed_keys}" "${wanted_keys}" >&2
	# Add missing keys
	comm -1 -3 "${installed_keys}" "${wanted_keys}" >> ~/.ssh/authorized_keys
	rm -f "${installed_keys}" "${wanted_keys}"
	chmod 0600 ~/.ssh/authorized_keys
elif ! [ -f ~/.ssh/authorized_keys ]; then
	install -v -m 0600 "${REPO}/dot.ssh/authorized_keys" ~/.ssh/authorized_keys
fi

for f in alert-on-exit benv.sh generate-tags generate-tagsd \
    screen-wrapper.sh ssh-wrapper.sh fixscreen make start-screen tf update-profile \
    fping-wait.sh \
    gen-ssh k \
    lscolors lscolors 24-bit-color.sh; do
	if [ -L ~/bin/${f} ]; then
		rm -f ~/bin/${f}
	fi
done
if [ -L ~/.supp ]; then
	rm -f ~/.supp
fi

link_dotfile dot.bash_logout
link_dotfile dot.bash_profile
link_dotfile dot.bashrc
link_dotfile dot.ctags
link_dotfile dot.git-prompt.conf
preserve_as_local .gitconfig
link_dotfile dot.gitconfig
link_dotfile dot.gitignore
link_dotfile dot.inputrc
link_dotfile dot.lessfilter
copy_dotfile dot.login_conf .login_conf
link_dotfile dot.nanorc
link_dotfile dot.profile.common
link_dotfile dot.logout.common
link_dotfile dot.screenrc
link_dotfile dot.tmux.conf
link_dotfile dot.valgrindrc
link_dotfile dot.vimrc
link_dotfile dot.zlogout
link_dotfile dot.claude/statusline-command.sh .claude/statusline-command.sh
link_dotfile dot.claude/CLAUDE.md .claude/CLAUDE.md
install_claude_skills
link_dotfile dot.rc.common
link_dotfile dot.env.common
link_dotfile dot.zprofile
link_dotfile dot.zshenv
preserve_as_local .zshrc
link_dotfile dot.zshrc

sync_dir dot.config .config

mkdir -p ~/.tmux/plugins
link_dotfile dot.tmux/plugins/tpm .tmux/plugins/tpm
link_dotfile dot.zpool.d

# Process private/local dotfile repos listed in ~/.local.profile-repo
if [ -f ~/.local.profile-repo ]; then
	install -v -m 0700 -d "${REPO}/local.d"
	while read -r _repo_url; do
		case "${_repo_url}" in
		""|\#*) continue ;;
		esac
		_repo_name="${_repo_url##*/}"
		_repo_name="${_repo_name%.git}"
		_repo_dir="${REPO}/local.d/${_repo_name}"
		if [ -d "${_repo_dir}/.git" ]; then
			echo "Updating local repo: ${_repo_name}"
			git -C "${_repo_dir}" fetch origin --depth=1
			git -C "${_repo_dir}" reset --hard origin/HEAD
		else
			echo "Cloning local repo: ${_repo_name}"
			git clone --depth=1 "${_repo_url}" "${_repo_dir}"
		fi
		if [ -x "${_repo_dir}/install.sh" ]; then
			echo "Running ${_repo_name}/install.sh"
			REPO="${_repo_dir}" sh "${_repo_dir}/install.sh"
		fi
	done < ~/.local.profile-repo
fi

if which npm >/dev/null 2>&1 && [ "$(id -u)" != "0" ]; then
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

#if which pip >/dev/null 2>&1; then
#	pip install tmuxomatic --upgrade --user
#fi
