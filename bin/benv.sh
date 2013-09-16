#! /bin/sh
# $Id$

exec env MAKEOBJDIRPREFIX=${HOME}/tmp/obj __MAKE_CONF=/dev/null SRCCONF=/dev/null "$@"
