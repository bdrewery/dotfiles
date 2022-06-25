#! /bin/sh
# $Id$

WANTED_APPS="vim screen svn git ruby tmux ctags cscope python bash zsh gvim pygmentize"
cd ~
REPO=.profile-repo
chmod 0700 "${REPO}"

install -v -m 0700 -d ~/.generate-tagsd
install -v -m 0700 -d ~/.screen
install -v -m 0700 -d ~/.ssh
install -v -m 0700 -d ~/.vimundo
install -v -m 0700 -d ~/bin

rm -rf ~/.vim 2>/dev/null
ln -s ${REPO}/dot.vim ~/.vim

chmod 0700 ~/.viminfo > /dev/null 2>&1

rm -rf ~/.zsh 2>/dev/null
ln -fs ${REPO}/dot.zsh ~/.zsh

if [ -f ~/.ssh/authorized_keys ]; then
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
else
	install -v -m 0600 ${REPO}/dot.ssh/authorized_keys ~/.ssh/authorized_keys
fi

for f in alert-on-exit.sh benv.sh generate-tags generate-tagsd \
    screen-wrapper.sh fixscreen make start-screen update-profile \
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

ln -fs ${REPO}/dot.env.common ~/.env.common
ln -fs ${REPO}/dot.zprofile ~/.zprofile
ln -fs ${REPO}/dot.zshenv ~/.zshenv

ln -hfs ${REPO}/dot.zpool.d ~/.zpool.d

mkdir -p ~/.tmux/plugins
# XXX: Need a reldir install
ln -fs ../../${REPO}/dot.tmux/plugins/tpm ~/.tmux/plugins/tpm

if [ -f ~/.zshrc ] && [ ! -L ~/.zshrc ] && [ ! -L ~/.zshrc.local ] &&
    [ ! -f ~/.zshrc.local ]; then
	mv ~/.zshrc ~/.zshrc.local
fi
ln -fs ${REPO}/dot.zshrc ~/.zshrc

### Look for needed programs
check_for() {
  which $1 > /dev/null 2>&1
  if [ $? -eq 1 ]; then
    echo "$1 missing"
  fi
}

#if which pip >/dev/null 2>&1; then
#	pip install tmuxomatic --upgrade --user
#fi

for app in ${WANTED_APPS}; do
  check_for $app
done
