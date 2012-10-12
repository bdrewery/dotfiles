#! /bin/sh
# $Id$

while true; 
do 
 echo "$@";
 "$@";
 echo "Program terminated..sleeping"
 sleep 10
done
