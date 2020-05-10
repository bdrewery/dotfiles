#! /bin/sh
# $Id$

update() {
	cd ~/.profile-repo
	git fetch origin --depth=1
	git reset --hard origin/master
	git reflog expire --expire-unreachable=all --all
	git gc --prune=all
	git submodule init
	#if [ $(git version | awk '{print $3}' | cut -d . -f 1) -ge 2 ]; then
	#	git submodule update --depth=1
	#else
	git submodule update
	#fi
	exec ./install.sh
}
update
