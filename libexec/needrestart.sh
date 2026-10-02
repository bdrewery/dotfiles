#! /bin/sh

if [ -f /var/run/reboot-required ]; then
	echo "***** REBOOT REQUIRED *****"
	cat /var/run/reboot-required
elif command -v needrestart >/dev/null 2>&1 &&
    needrestart -k -p 2>/dev/null | grep -q "^CRIT"; then
	echo "***** REBOOT REQUIRED *****"
fi
