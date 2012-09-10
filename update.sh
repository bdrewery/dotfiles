#! /bin/bash
# $Id$

WANTED_APPS="vim screen svn git ruby"

cd ~/.profile-repo
svn up

if [ -d git-prompt ]; then
  pushd git-prompt
  git pull && git gc
  popd
else
  git clone git://github.com/lvv/git-prompt.git
fi

install -v -m 0700 -d ~/.ssh
install -v -m 0700 -d ~/bin
install -v -m 0700 -d ~/.screen

rm -rf ~/.vim 2>/dev/null
cp -r dot.vim ~/.vim
find ~/.vim -type d -name ".svn" -exec rm -rf {} \; 2>/dev/null

install -v -m 0700 -d ~/.vimundo
install -v -m 0700 -d ~/.vim
chmod 0700 ~/.viminfo > /dev/null 2>&1

install -v -m 0600 dot.ssh/authorized_keys ~/.ssh/authorized_keys
install -v bin/screen-wrapper.sh ~/bin/screen-wrapper.sh
install -v bin/start-screen ~/bin/start-screen
install -v bin/update-profile ~/bin/update-profile
install -v dot.inputrc ~/.inputrc
install -v dot.vimrc ~/.vimrc
install -v dot.zshrc ~/.zshrc
install -v dot.login_conf ~/.login_conf
install -v dot.profile.common ~/.profile.common
install -v dot.bashrc ~/.bashrc
install -v dot.nanorc ~/.nanorc
install -v dot.gitconfig ~/.gitconfig
install -v dot.supp ~/.supp
install -v dot.valgrindrc ~/.valgrindrc
install -v dot.bash_logout ~/.bash_logout
install -v dot.git-prompt.conf ~/.git-prompt.conf
install -v dot.screenrc ~/.screenrc

! [ -d vim-ruby ] &&  git clone git://github.com/vim-ruby/vim-ruby.git
pushd vim-ruby
git pull && git gc
which ruby > /dev/null 2>&1 && bin/vim-ruby-install.rb -d ~/.vim/
popd

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
