#! /bin/sh
# $Id$

while /bin/true; 
do 
 echo "$@";
 $@;
 echo "Program terminated..sleeping"
 sleep 10
done
