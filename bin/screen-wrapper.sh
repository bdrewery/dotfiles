#! /bin/sh
# $Id$

sigint_handler() {
        exec ${SHELL}
}
[ -n "${SHELL}" ] && trap sigint_handler INT TERM EXIT

export RAN_FROM_CRON=1
while true; 
do 
 echo "$@";
 "$@";
 echo "Program terminated..sleeping"
 sleep 10
done
