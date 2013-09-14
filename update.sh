#! /bin/sh
# $Id$

WANTED_APPS="vim screen svn git ruby tmux ctags cscope python bash zsh gvim"

cd ~/.profile-repo
svn upgrade
svn up

if [ -d git-prompt ]; then
  cd git-prompt
  git reset --hard
  git pull && git gc
  cd ..
else
  git clone https://github.com/lvv/git-prompt.git
fi

install -v -m 0700 -d ~/.ssh
install -v -m 0700 -d ~/bin
install -v -m 0700 -d ~/.screen

rm -rf ~/.vim 2>/dev/null
cp -r dot.vim ~/.vim
find ~/.vim -type d -name ".svn" -exec rm -rf {} + 2>/dev/null

install -v -m 0700 -d ~/.vimundo
install -v -m 0700 -d ~/.vim
chmod 0700 ~/.viminfo > /dev/null 2>&1

if [ -f ~/.ssh/authorized_keys ]; then
	# Don't overwrite it, just ensure all keys are added, and alert
	# on unknown keys
	installed_keys=$(mktemp -t keys.XXXXXXXXXX)
	wanted_keys=$(mktemp -t keys.XXXXXXXXXX)
	sort -u ~/.ssh/authorized_keys | egrep -v '(^$|^#)' > ${installed_keys}
	sort -u dot.ssh/authorized_keys | egrep -v '(^$|^#)' > ${wanted_keys}
	echo "### Unknown SSH Keys" >&2
	comm -2 -3 ${installed_keys} ${wanted_keys} >&2
	# Add missing keys
	comm -1 -3 ${installed_keys} ${wanted_keys} >> ~/.ssh/authorized_keys
	rm -f ${installed_keys} ${wanted_keys}
	chmod 0600 ~/.ssh/authorized_keys
else
	install -v -m 0600 dot.ssh/authorized_keys ~/.ssh/authorized_keys
fi
install -v bin/screen-wrapper.sh ~/bin/screen-wrapper.sh
install -v bin/start-screen ~/bin/start-screen
install -v bin/update-profile ~/bin/update-profile
install -v bin/generate-tags ~/bin/generate-tags
install -v dot.ctags ~/.ctags
install -v dot.inputrc ~/.inputrc
install -v dot.vimrc ~/.vimrc
install -v dot.zshrc ~/.zshrc
install -v dot.tmuxrc ~/.tmuxrc
install -v dot.login_conf ~/.login_conf
install -v dot.profile.common ~/.profile.common
install -v dot.bash_profile ~/.bash_profile
install -v dot.bashrc ~/.bashrc
install -v dot.nanorc ~/.nanorc
[ -f ~/.keep-gitconfig ] || install -v dot.gitconfig ~/.gitconfig
install -v dot.gitignore ~/.gitignore
install -v dot.supp ~/.supp
install -v dot.valgrindrc ~/.valgrindrc
install -v dot.bash_logout ~/.bash_logout
install -v dot.git-prompt.conf ~/.git-prompt.conf
install -v dot.screenrc ~/.screenrc

! [ -d vim-ruby ] &&  git clone https://github.com/vim-ruby/vim-ruby.git
cd vim-ruby
git pull && git gc
which ruby > /dev/null 2>&1 && bin/vim-ruby-install.rb -d ~/.vim/
cd ..

### Look for needed programs
check_for() {
  which $1 > /dev/null 2>&1
  if [ $? -eq 1 ]; then
    echo "$1 missing"
  fi
}

for app in ${WANTED_APPS}; do
  check_for $app
done
