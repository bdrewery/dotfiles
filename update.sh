#! /bin/sh

update() {
	cd ~/.profile-repo
	git fetch -q --no-recurse-submodules origin --depth=1
	git reset --hard origin/master
	git submodule -q update --init --depth=1
	git reflog expire --expire-unreachable=all --all
	git gc --prune=all --quiet
	exec ./install.sh
}
update
