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
max_orig=60
max="${max_orig}"
inc=10
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
	if read -t "${sleep}" _; then
		max="${max_orig}"
	else
		max=$((max + inc))
	fi
done
