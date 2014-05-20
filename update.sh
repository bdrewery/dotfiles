#! /bin/sh
# $Id$

cd ~/.profile-repo
git pull
git submodule init
git submodule update --depth=1
exec ./install.sh
