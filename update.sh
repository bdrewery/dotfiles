#! /bin/sh

update() {
	cd ~/.profile-repo
	git fetch origin --depth=1
	git submodule update --init --depth=1
	git reset --hard origin/master
	git reflog expire --expire-unreachable=all --all
	git gc --prune=all
	exec ./install.sh
}
update
