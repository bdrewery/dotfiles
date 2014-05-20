#! /bin/sh
# $Id$

cd ~/.profile-repo
git fetch origin --depth=1
git reset --hard origin/master
git reflog expire --expire-unreachable=all --all
git gc --prune=all
git submodule init
git submodule update --depth=1
exec ./install.sh
