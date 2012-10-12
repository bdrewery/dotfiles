#! /bin/sh
# $Id$

export RAN_FROM_CRON=1
while true; 
do 
 echo "$@";
 "$@";
 echo "Program terminated..sleeping"
 sleep 10
done
