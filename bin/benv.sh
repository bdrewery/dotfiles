#! /bin/sh
# $Id$

exec env MAKEOBJDIRPREFIX=~/tmp/obj __MAKE_CONF=/dev/null SRCCONF=/dev/null "$@"
