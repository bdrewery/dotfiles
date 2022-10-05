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
max=60
while true;
do
	sleep="${max}"
	echo "# screen-wrapper.sh $@";
	fixscreen "$@";
	ret="$?"
	echo "Program terminated ${ret}..sleeping"
	case "${ret}" in
	0|130)
		# 130 = SIGINT
		sleep=0
		continue
		;;
	esac
	read -t "${sleep}" _ || :
done
