#! /bin/sh
# $Id$

WANTED_APPS="vim screen svn"

cd ~/.profile-repo
svn up

install -v -m 0700 -d ~/.ssh
install -v -m 0700 -d ~/bin
install -v -m 0700 -d ~/.screen

rm -rf ~/.vim 2>/dev/null
cp -r dot.vim ~/.vim
find ~/.vim -type d -name ".svn" -exec rm -rf {} \; 2>/dev/null


install -v -m 0600 dot.ssh/authorized_keys ~/.ssh/authorized_keys
install -v bin/screen-wrapper.sh ~/bin/screen-wrapper.sh
install -v bin/start-screen ~/bin/start-screen
install -v bin/update-profile ~/bin/update-profile
install -v dot.vimrc ~/.vimrc
install -v dot.bashrc ~/.bashrc
install -v dot.nanorc ~/.nanorc


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
