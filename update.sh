#! /bin/sh
# $Id$

cd ~/.profile-repo
svn upgrade
svn up
exec ./install.sh
