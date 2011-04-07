#! /bin/bash
# $Id$

WANTED_APPS="vim screen svn git"

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
# Link the sql.vim to sqloracle.vim
ln -s ~/.vim/syntax/sqloracle.vim ~/.vim/syntax/sql.vim

install -v -m 0600 dot.ssh/authorized_keys ~/.ssh/authorized_keys
install -v bin/screen-wrapper.sh ~/bin/screen-wrapper.sh
install -v bin/start-screen ~/bin/start-screen
install -v bin/update-profile ~/bin/update-profile
install -v dot.vimrc ~/.vimrc
install -v dot.bashrc ~/.bashrc
install -v dot.nanorc ~/.nanorc
install -v dot.gitconfig ~/.gitconfig
install -v dot.supp ~/.supp
install -v dot.valgrindrc ~/.valgrindrc
install -v dot.bash_logout ~/.bash_logout
install -v dot.git-prompt.conf ~/.git-prompt.conf
install -v dot.screenrc ~/.screenrc


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
