#! /bin/sh

cd ~
REPO=.profile-repo
chmod 0700 "${REPO}"

install -v -m 0700 -d ~/.generate-tagsd
install -v -m 0700 -d ~/.screen
install -v -m 0700 -d ~/.ssh
install -v -m 0700 -d ~/.claude
install -v -m 0700 -d ~/.claude/skills
install -v -m 0700 -d ~/.vimundo
install -v -m 0700 -d ~/bin

rm -rf ~/.vim 2>/dev/null
ln -s ${REPO}/dot.vim ~/.vim

chmod 0700 ~/.viminfo > /dev/null 2>&1

rm -rf ~/.zsh 2>/dev/null
ln -fs ${REPO}/dot.zsh ~/.zsh

if [ -f ~/.ssh/authorized_keys ] && ! [ -d /usr/local/share/system ]; then
	# Don't overwrite it, just ensure all keys are added, and alert
	# on unknown keys
	installed_keys=$(mktemp -t keys.XXXXXXXXXX)
	wanted_keys=$(mktemp -t keys.XXXXXXXXXX)
	sort -u ~/.ssh/authorized_keys | egrep -v '(^$|^#)' > ${installed_keys}
	sort -u ${REPO}/dot.ssh/authorized_keys | egrep -v '(^$|^#)' > ${wanted_keys}
	echo "### Unknown SSH Keys" >&2
	comm -2 -3 ${installed_keys} ${wanted_keys} >&2
	# Add missing keys
	comm -1 -3 ${installed_keys} ${wanted_keys} >> ~/.ssh/authorized_keys
	rm -f ${installed_keys} ${wanted_keys}
	chmod 0600 ~/.ssh/authorized_keys
elif ! [ -f ~/.ssh/authorized_keys ]; then
	install -v -m 0600 ${REPO}/dot.ssh/authorized_keys ~/.ssh/authorized_keys
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
ln -fs ${REPO}/dot.bash_logout ~/.bash_logout
ln -fs ${REPO}/dot.bash_profile ~/.bash_profile
ln -fs ${REPO}/dot.bashrc ~/.bashrc
ln -fs ${REPO}/dot.ctags ~/.ctags
ln -fs ${REPO}/dot.git-prompt.conf ~/.git-prompt.conf
if [ -f ~/.gitconfig ] && [ ! -L ~/.gitconfig ]; then
	mv ~/.gitconfig ~/.gitconfig.local
fi
ln -fs ${REPO}/dot.gitconfig ~/.gitconfig
ln -fs ${REPO}/dot.gitignore ~/.gitignore
ln -fs ${REPO}/dot.inputrc ~/.inputrc
ln -fs ${REPO}/dot.lessfilter ~/.lessfilter
[ -L ~/.login_conf ] && rm -f ~/.login_conf
install -C -v ${REPO}/dot.login_conf ~/.login_conf
ln -fs ${REPO}/dot.nanorc ~/.nanorc
ln -fs ${REPO}/dot.profile.common ~/.profile.common
ln -fs ${REPO}/dot.logout.common ~/.logout.common
ln -fs ${REPO}/dot.screenrc ~/.screenrc
ln -fs ${REPO}/dot.tmux.conf ~/.tmux.conf
ln -fs ${REPO}/dot.valgrindrc ~/.valgrindrc
ln -fs ${REPO}/dot.vimrc ~/.vimrc
ln -fs ${REPO}/dot.zlogout ~/.zlogout
ln -fs ../${REPO}/dot.claude/statusline-command.sh ~/.claude/
ln -fs ../${REPO}/dot.claude/CLAUDE.md ~/.claude/CLAUDE.md
for skill in ${REPO}/dot.claude/skills/*; do
	case "${skill}" in
	# empty
	"${REPO}/dot.claude/skills/*") continue ;;
	esac
	if [ -d ~/.claude/skills/"${skill##*/}" ] && \
	    [ ! -L ~/.claude/skills/"${skill##*/}" ]; then
		rm -rf ~/.claude/skills/"${skill##*/}"
	fi
	ln -nfs ../../"${skill}" ~/.claude/skills/"${skill##*/}"
done
# Remove skills that no longer exist
for skill in ${HOME}/.claude/skills/*; do
	case "${skill}" in
	# empty
	"${HOME}/.claude/skills/*") continue ;;
	esac
	if [ ! -L "${skill}" ]; then
		continue
	fi
	linkdest="$(readlink "${skill}")"
	case "${linkdest}" in
	"../../${REPO}/dot.claude/skills/"*) ;;
	*) continue ;;
	esac
	if [ ! -r "${skill}" ]; then
		echo "Removing stale profile-repo skill: ${skill##*/}"
		rm -f "${skill}"
	fi
done
ln -fs ../${REPO}/dot.claude/CLAUDE.md ~/.claude/CLAUDE.md

ln -fs ${REPO}/dot.rc.common ~/.rc.common
ln -fs ${REPO}/dot.env.common ~/.env.common
ln -fs ${REPO}/dot.zprofile ~/.zprofile
ln -fs ${REPO}/dot.zshenv ~/.zshenv

rsync -avH ${REPO}/dot.config/ ~/.config/

mkdir -p ~/.tmux/plugins
# XXX: Need a reldir install
ln -nfs ../../${REPO}/dot.tmux/plugins/tpm ~/.tmux/plugins/tpm
ln -nfs ${REPO}/dot.zpool.d ~/.zpool.d

if [ -f ~/.zshrc ] && [ ! -L ~/.zshrc ] && [ ! -L ~/.zshrc.local ] &&
    [ ! -f ~/.zshrc.local ]; then
	mv ~/.zshrc ~/.zshrc.local
fi
ln -fs ${REPO}/dot.zshrc ~/.zshrc

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
			(cd "${_repo_dir}" && ./install.sh)
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
