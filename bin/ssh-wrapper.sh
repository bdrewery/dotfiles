#! /bin/sh

extract_hostname() {
	local arg uhost host port

	while [ "$#" -gt 0 ]; do
		arg="${1}"
		case "${arg}" in
		-p)
			port="${2?}"
			shift
			;;
		ssh)
			;;
		-b|-B|-J)
			return 1
			;;
		-*)
			;;
		esac
		shift
	done
	uhost="${arg:?}"
	host="${uhost##*@}"
	echo "${host}${port:+:${port}}"
}

sigint_handler() {
	exit
}
if [ -n "${SHELL-}" ]; then
	trap sigint_handler INT
fi

if ! which fping >/dev/null 2>&1; then
	exec "$@"
fi

if [ "$#" -lt 1 ]; then
	echo "Usage: $0 [ssh options] <user@hostname> [command]" >&2
	exit 1
fi

hostname="$(extract_hostname "$@" || echo)"
case "${hostname}" in
*:*)
	port="${hostname##*:}"
	hostname="${hostname%:*}"
	;;
*)
	port=
	;;
esac
if [ -z "${hostname}" ] || [ -z "${port}" ]; then
	exec "$@"
fi

while fping-wait.sh "${hostname}:${port}"; do
	exec "$@"
done
