#! /bin/sh

_ARGS="$@"
sigint_handler() {
	echo
	echo "# ${_ARGS}"
	exec ${SHELL}
}
if [ -n "${SHELL}" ]; then
	trap sigint_handler INT TERM EXIT
fi

export RAN_FROM_CRON=1
max=3
n=1
inc=1
while true;
do
	sleep="${n}"
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
		n="${max}"
	else
		n=$((n + inc))
	fi
	if [ "${n}" -gt "${max}" ]; then
		n=1
	fi
done
