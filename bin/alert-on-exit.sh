#! /bin/sh

if [ -z "${PROWL_APIKEY}" ]; then
	echo "* No PROWL_APIKEY set, not alerting." >&2
	exec "$@"
fi

echo "* Will alert on PROWL_APIKEY=${PROWL_APIKEY}..." >&2

time_l=
if /usr/bin/time -l true >/dev/null 2>&1; then
	time_l="-l"
fi

/usr/bin/time ${time_l} "$@"
ret=$?

if [ ${ret} -eq 0 ]; then
	result="succeeded"
else
	result="failed (${ret})"
fi

echo "* Sending prowl alert..." >&2

curl -so /dev/null \
        https://api.prowlapp.com/publicapi/add \
        -F apikey=${PROWL_APIKEY} \
        -F application="alert-on-exit $1" \
        -F event="Command ${result}" \
        -F description="Command: $*" &

exit ${ret}
