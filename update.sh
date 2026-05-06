#! /bin/sh

update() {
	cd ~/.profile-repo
	git fetch --no-recurse-submodules origin --depth=1
	git reset --hard origin/master
	git submodule update --init --depth=1
	git reflog expire --expire-unreachable=all --all
	git gc --prune=all --quiet
	exec ./install.sh
}
update
