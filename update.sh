#! /bin/sh
# $Id$

cd ~/.profile-repo
git pull
git submodule init
git submodule update
exec ./install.sh
