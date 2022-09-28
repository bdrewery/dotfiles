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
cnt=0
max=60
while true;
do
	echo "# screen-wrapper.sh $@";
	fixscreen "$@";
	ret="$?"
	echo "Program terminated ${ret}..sleeping"
	case "${ret}" in
	0|130)
		# 130 = SIGINT
		cnt=0
		continue
		;;
	esac
	if [ "${cnt}" -lt 5 ]; then
		sleep 1
	else
		sleep "${cnt}"
	fi
	cnt=$((cnt + 1))
	if [ "${cnt}" -gt "${max}" ]; then
		cnt=0
	fi
done
