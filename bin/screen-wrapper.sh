#! /bin/sh
# $Id$

_ARGS="$@"
sigint_handler() {
	echo
	echo "# ${_ARGS}"
	exec ${SHELL}
}
[ -n "${SHELL}" ] && trap sigint_handler INT TERM EXIT

export RAN_FROM_CRON=1
while true;
do
	echo "# $@";
	"$@";
	echo "Program terminated..sleeping"
	sleep 10
done
