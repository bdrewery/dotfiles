#! /bin/sh

fping() {
	local ret

	ret=0
	command fping -q "$@" || ret="$?"
	case "${ret}" in
	2|3)
		error="$(command fping "$@" 2>&1 || :)"
		echo "[!] fping: ${error}" >&2
		backoff
		;;
	esac
	case "${ret}" in
	3)
		# Invalid arguments
		exit 1
		;;
	esac
	return "${ret}"
}

checkport() {
	local hostname="$1"
	local port="$2"

	if [ -z "${port}" ]; then
		return 0
	fi

	nc -w 1 -z "${hostname}" "${port}" >/dev/null 2>&1
}

sigint_handler() {
	exit
}

if [ "$#" -lt 1 ]; then
	echo "Usage: $0 <hostname[:port]>" >&2
	exit 1
fi
hostname="${1}"
port=
shift
case "${hostname}" in
*:*)
	port="${hostname##*:}"
	hostname="${hostname%:*}"
	;;
esac

if ! which fping >/dev/null 2>&1; then
	echo "[!] fping not installed" >&2
	exec "$@"
fi

if [ -n "${port}" ]; then
	if ! which nc >/dev/null 2>&1; then
		echo "[!] netcat not installed" >&2
		exec "$@"
	fi
fi

if [ -n "${SHELL-}" ]; then
	trap sigint_handler INT
fi

MAX=60
PERIOD=1
INCREMENT="1.5"
TRIES=0
backoff() {
	if read -t "${PERIOD}" _; then
		return
	fi
	# ZSH supports decimals but sh/bash do not so use bc(1).
	PERIOD="$(echo "${PERIOD} * ${INCREMENT}" | bc)"
	TRIES=$((TRIES + 1))
	if [ "${TRIES}" -gt "${MAX}" ]; then
		#exit 1
		PERIOD=1
	fi
}

while :; do
	if ! fping -r 0 "${hostname}" ||
	   ! checkport "${hostname}" "${port}"; then
		echo "[%] Waiting for host '${hostname}${port:+:${port}}' to become available..." >&2
		until fping -B "${INCREMENT}" -r "${MAX}" "${hostname}"; do
			echo "[%] Host '${hostname}${port:+:${port}}' is still down. Waiting..." >&2
		done
		if ! checkport "${hostname}" "${port}"; then
			echo "[%] Host '${hostname}' is up but port '${port}' is down..." >&2
			backoff
			continue
		fi
		echo "[X] Host '${hostname}${port:+:${port}}' is up. Connecting..." >&2
	fi
	break
done
