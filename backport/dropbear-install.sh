#!/usr/bin/env bash

set -e

if [ -f ./dropbear ] && [ -f ./dbclient ] && [ -f ./dropbearkey ] && [ -f ./scp ]; then
	BUILD_DIR=$(pwd)
elif [ -f ../dropbear ] && [ -f ../dbclient ] && [ -f ../dropbearkey ] && [ -f ../scp ]; then
	BUILD_DIR=$(cd .. && pwd)
else
	echo "Error: could not find dropbear, dbclient, dropbearkey, and scp in the current directory or its parent." >&2
	exit 1
fi

install -m 755 "${BUILD_DIR}/dropbear" /usr/sbin/dropbear
install -m 755 "${BUILD_DIR}/dbclient" /usr/bin/dbclient
install -m 755 "${BUILD_DIR}/dropbearkey" /usr/bin/dropbearkey

if [ -e /usr/bin/scp ]; then
	SCP_INSTALL_PATH=/usr/bin/dbscp
else
	SCP_INSTALL_PATH=/usr/bin/scp
fi
install -m 755 "${BUILD_DIR}/scp" "${SCP_INSTALL_PATH}"

mkdir -p /etc/dropbear
chmod 700 /etc/dropbear

if [ -d /etc/skel ]; then
	mkdir -p /etc/skel/.ssh
	chmod 700 /etc/skel/.ssh
fi

if [ ! -f /etc/dropbear/dropbear_rsa_host_key ]; then
	/usr/bin/dropbearkey -t rsa -s 4096 -f /etc/dropbear/dropbear_rsa_host_key
fi

if [ ! -f /etc/dropbear/dropbear_ecdsa_host_key ]; then
	/usr/bin/dropbearkey -t ecdsa -s 521 -f /etc/dropbear/dropbear_ecdsa_host_key
fi

if [ ! -f /etc/dropbear/dropbear_ed25519_host_key ]; then
	/usr/bin/dropbearkey -t ed25519 -f /etc/dropbear/dropbear_ed25519_host_key
fi

chmod 0400 /etc/dropbear/dropbear_*_host_key /etc/dropbear/dropbear_*_host_key.pub 2>/dev/null || true

touch /var/run/dropbear.pid
chmod 644 /var/run/dropbear.pid

if [ -d /etc/rc.d/init.d ] && [ -d /etc/rc.d/rc3.d ] && [ -d /etc/rc.d/rc5.d ]; then
	cat > /etc/rc.d/init.d/dropbear <<'EOF'
#!/bin/sh
#
# dropbear    Start/Stop the Dropbear SSH daemon
#
# chkconfig: 345 55 25
# description: Dropbear SSH server
# processname: dropbear
# pidfile: /var/run/dropbear.pid

DAEMON=/usr/sbin/dropbear
DROPBEARKEY=/usr/bin/dropbearkey
PIDFILE=/var/run/dropbear.pid
KEYDIR=/etc/dropbear
PORT=22

[ -x "$DAEMON" ] || exit 1
[ -x "$DROPBEARKEY" ] || exit 1

create_keys() {
	mkdir -p "$KEYDIR"

	if [ ! -f "$KEYDIR/dropbear_rsa_host_key" ]; then
		"$DROPBEARKEY" -t rsa -s 4096 -f "$KEYDIR/dropbear_rsa_host_key"
	fi
	if [ ! -f "$KEYDIR/dropbear_ecdsa_host_key" ]; then
		"$DROPBEARKEY" -t ecdsa -s 521 -f "$KEYDIR/dropbear_ecdsa_host_key"
	fi
	if [ ! -f "$KEYDIR/dropbear_ed25519_host_key" ]; then
		"$DROPBEARKEY" -t ed25519 -f "$KEYDIR/dropbear_ed25519_host_key"
	fi

	chmod 0400 "$KEYDIR"/dropbear_*_host_key "$KEYDIR"/dropbear_*_host_key.pub 2>/dev/null || true
}

pid_is_live_dropbear() {
	_PID="$1"
	[ -n "$_PID" ] || return 1
	kill -0 "$_PID" 2>/dev/null || return 1
	CMDLINE="$(tr '\000' ' ' < "/proc/$_PID/cmdline" 2>/dev/null || true)"
	case "$CMDLINE" in
		"$DAEMON"*)
			return 0
			;;
		*)
			return 1
			;;
	esac
}

pid_matches_instance() {
	_PID="$1"
	[ -n "$_PID" ] || return 1
	CMDLINE="$(tr '\000' ' ' < "/proc/$_PID/cmdline" 2>/dev/null || true)"
	case "$CMDLINE" in
		"$DAEMON"*"-p ${PORT}"*|"$DAEMON"*"-p${PORT}"*)
			return 0
			;;
		*)
			return 1
			;;
	esac
}

get_dropbear_pid() {
	if [ -f "$PIDFILE" ]; then
		PID="$(cat "$PIDFILE" 2>/dev/null)"
		if pid_is_live_dropbear "$PID" && pid_matches_instance "$PID"; then
			echo "$PID"
			return 0
		fi
	fi

	for PID in $(pidof dropbear 2>/dev/null); do
		if pid_is_live_dropbear "$PID" && pid_matches_instance "$PID"; then
			echo "$PID"
			return 0
		fi
	done

	return 1
}

start() {
	echo -n "Starting dropbear: "
	create_keys

	PID="$(get_dropbear_pid 2>/dev/null || true)"
	if [ -n "$PID" ]; then
		echo "already running"
		echo "$PID" > "$PIDFILE"
		return 0
	fi

	rm -f "$PIDFILE"

	"$DAEMON" \
		-p ${PORT} \
		-P "$PIDFILE" \
		-w

	sleep 1

	PID="$(get_dropbear_pid 2>/dev/null || true)"
	if [ -n "$PID" ]; then
		echo "$PID" > "$PIDFILE"
		echo "ok"
		return 0
	fi

	echo "failed"
	return 1
}

stop() {
	echo -n "Stopping dropbear: "

	PID="$(get_dropbear_pid 2>/dev/null || true)"
	if [ -z "$PID" ]; then
		rm -f "$PIDFILE"
		echo "not running"
		return 0
	fi

	kill "$PID" 2>/dev/null || true
	sleep 1

	if kill -0 "$PID" 2>/dev/null; then
		kill -9 "$PID" 2>/dev/null || true
	fi

	rm -f "$PIDFILE"
	echo "ok"
	return 0
}

status() {
	PID="$(get_dropbear_pid 2>/dev/null || true)"
	if [ -n "$PID" ]; then
		echo "$PID" > "$PIDFILE"
		echo "dropbear (pid $PID) is running"
		return 0
	fi

	rm -f "$PIDFILE"
	echo "dropbear is stopped"
	return 3
}

restart() {
	stop
	start
}

case "$1" in
	start)
		start
		;;
	stop)
		stop
		;;
	restart|reload)
		restart
		;;
	status)
		status
		;;
	*)
		echo "Usage: $0 {start|stop|restart|reload|status}"
		exit 1
		;;
esac

exit $?
EOF

	chmod 755 /etc/rc.d/init.d/dropbear

	if command -v chkconfig >/dev/null 2>&1; then
		chkconfig --add dropbear || true
		chkconfig dropbear on || true
	else
		if [ ! -d /etc/rc.d/rc0.d ]; then mkdir -p /etc/rc.d/rc0.d; fi
		if [ ! -d /etc/rc.d/rc6.d ]; then mkdir -p /etc/rc.d/rc6.d; fi

		ln -sf ../init.d/dropbear /etc/rc.d/rc3.d/S55dropbear
		ln -sf ../init.d/dropbear /etc/rc.d/rc5.d/S55dropbear
		ln -sf ../init.d/dropbear /etc/rc.d/rc0.d/K25dropbear
		ln -sf ../init.d/dropbear /etc/rc.d/rc6.d/K25dropbear
	fi
else
	echo "SysVinit layout not detected; skipping init script installation."
fi

perl -pi -e 's/^([^#]*22\/tcp)/#$1/' /etc/services
perl -pi -e 's/(ftp\s+21\/tcp)/$1\nssh\t\t22\/tcp/' /etc/services
echo "Added ssh 22/tcp to /etc/services"

echo ""
echo "Installed:"
echo "  /usr/sbin/dropbear"
echo "  /usr/bin/dbclient"
echo "  /usr/bin/dropbearkey"
echo "  ${SCP_INSTALL_PATH}"
echo ""

if [ -d /etc/skel/.ssh ]; then
	echo "  /etc/skel/.ssh"
fi

if [ -f /etc/rc.d/init.d/dropbear ]; then
	echo ""
	echo "Init script:"
	echo "  /etc/rc.d/init.d/dropbear"
	echo ""
	echo "To start now:"
	echo "  /etc/rc.d/init.d/dropbear start"
	echo ""
	echo "To check status:"
	echo "  /etc/rc.d/init.d/dropbear status"
fi
