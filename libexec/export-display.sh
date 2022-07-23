#! /bin/sh

if [ -z "${WSL_DISTRO_NAME-}" ]; then
        exit 0
fi

# https://x410.dev/cookbook/
# https://x410.dev/cookbook/wsl/using-x410-with-wsl2/
if which socat >/dev/null 2>&1; then
        PIDFILE=/tmp/socat.pid
	SOCKFILE="/tmp/.X11-unix/X0"
        mkdir -p "${SOCKFILE%/*}"
        if socat -V | grep -q VSOCK; then
                args="-b65536 UNIX-LISTEN:${SOCKFILE},fork,mode=777 VSOCK-CONNECT:2:6000"
        else
                args="-b65536 UNIX-LISTEN:${SOCKFILE},fork,mode=777 SOCKET-CONNECT:40:0:x0000x70170000x02000000x00000000"
        fi
	if [ -e "${PIDFILE}" ]; then
		if ! kill -0 $(cat "${PIDFILE}") 2>/dev/null; then
			rm -f "${SOCKFILE}"
		else
			echo "export DISPLAY=:0.0"
			exit 0
		fi
	fi
        if daemonize -p "${PIDFILE}" -- /usr/bin/socat ${args}; then
		echo "export DISPLAY=:0.0"
	fi
elif which ip >/dev/null 2>&1; then
        echo "export DISPLAY=$(ip route | grep default | awk '{print $3; exit;}'):0.0"
else
        echo "export DISPLAY=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2; exit;}'):0.0"
fi
