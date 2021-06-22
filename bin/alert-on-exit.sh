#! /bin/sh

if [ -z "${PROWL_APIKEY}" ]; then
	echo "* No PROWL_APIKEY set, not alerting." >&2
	exec "$@"
fi

echo "* Will alert on PROWL_APIKEY=${PROWL_APIKEY}..." >&2

/usr/bin/time -l "$@"
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
