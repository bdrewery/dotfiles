#! /bin/sh

extract_hostname() {
	local arg uh h

	for arg in "$@"; do
		case "${arg}" in
		ssh)
			continue
			;;
		-b|-B|-J)
			return 1
			;;
		-*)
			continue
			;;
		*)
			uh="${arg}"
			h="${uh##*@}"
			echo "${h}"
			return 0
			;;
		esac
	done
	return 0
}

extract_port() {
	local arg port

	while [ "$#" -gt 0 ]; do
		arg="${1}"
		case "${arg}" in
		-p)
			port="${2?}"
			echo "${port}"
			return 0
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
	echo "22"
}

if ! which fping >/dev/null 2>&1; then
	exec "$@"
fi

if [ "$#" -lt 1 ]; then
	echo "Usage: $0 [ssh options] <user@hostname> [command]" >&2
	exit 1
fi

hostname="$(extract_hostname "$@" || echo)"
port="$(extract_port "$@" || echo)"
if [ -z "${hostname}" ] || [ -z "${port}" ]; then
	exec "$@"
fi

while fping-wait.sh "${hostname}:${port}"; do
	exec "$@"
done
