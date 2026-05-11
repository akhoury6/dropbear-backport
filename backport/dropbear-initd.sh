#!/bin/sh
#
# dropbear    Start/Stop the Dropbear SSH daemon
#
# chkconfig: 345 55 25
# description: Dropbear SSH server
# processname: dropbear
# pidfile: /var/run/dropbear.pid


## CONFIGURATION
# Run 'dropbear --help' for a list of CLI parameters.
# This script injects -P (pidfile), do not specify one here.
DROPBEAR_FLAGS="-w -p 0.0.0.0:22"


## VARS
DAEMON_BASE=/usr/sbin/dropbear
DROPBEARKEY=/usr/bin/dropbearkey
PIDFILE=/var/run/dropbear.pid
KEYDIR=/etc/dropbear

[ -x "${DAEMON_BASE}" ] || exit 1
[ -x "${DROPBEARKEY}" ] || exit 1

case "$(file -b "${DAEMON_BASE}" | head -n 1)" in
	*executable*)
		DAEMON=/usr/sbin/dropbear ;;
	*script*)
		case "$(uname -m)" in
			i386) DAEMON="/usr/sbin/dropbear-386" ;;
			*) DAEMON="/usr/sbin/dropbear-486" ;;
		esac ;;
	*)
		exit 1 ;;
esac

[ -x "${DAEMON}" ] || exit 1


## HELPER FUNCTIONS
is_root() {
	[ "$(id -u)" -eq 0 ]
	return $?
}

is_all_host_keys_available() {
	if [ -f "${KEYDIR}/dropbear_rsa_host_key" ] && \
	   [ -f "${KEYDIR}/dropbear_ecdsa_host_key" ] && \
	   [ -f "${KEYDIR}/dropbear_ed25519_host_key" ]; then
		return 0
	fi
	return 1
}

is_any_host_key_available() {
	if [ -f "${KEYDIR}/dropbear_rsa_host_key" ] || \
	   [ -f "${KEYDIR}/dropbear_ecdsa_host_key" ] || \
	   [ -f "${KEYDIR}/dropbear_ed25519_host_key" ]; then
		return 0
	fi
	return 1
}

get_dropbear_pid() {
	if [ -f "${PIDFILE}" ]; then
		PIDFILE_PID="$(cat "${PIDFILE}" 2> /dev/null)"
		# Handle invalid PIDs
		case "${PIDFILE_PID}" in
			''|*[!0-9]*)
				clear_dropbear_pid
				return 1
				;;
		esac
		# Validate the PID against running processes
		if ps "${PIDFILE_PID}" 2> /dev/null | grep -q "$(basename "${DAEMON}")"; then
			echo "${PIDFILE_PID}"
			return 0
		fi
		# If the code reaches here, no running process has this pid. We silently clear it.
		clear_dropbear_pid
		return 1
	fi
	return 1
}

clear_dropbear_pid() {
	[ -f "${PIDFILE}" ] && rm -f "${PIDFILE}" > /dev/null 2>&1 || true
}

## COMMANDS
start() {
	if ! is_root; then
		echo "You must be root to start or stop dropbear."
		return 1
	fi

	if ! is_any_host_key_available; then
		echo "No host keys found in ${KEYDIR}."
		echo "Generate them with: $0 create-host-keys."
		return 1
	fi

	echo -n "Starting dropbear: "

	PID="$(get_dropbear_pid)"
	if [ -n "${PID}" ]; then
		echo "already running"
		return 0
	fi

	clear_dropbear_pid
	"${DAEMON}" -P "${PIDFILE}" ${DROPBEAR_FLAGS}
	sleep 1

	PID="$(get_dropbear_pid)"
	if [ -z "${PID}" ]; then
		echo "failed"
		return 1
	fi

	echo "ok"
	return 0
}

stop() {
	if ! is_root; then
		echo "You must be root to start or stop dropbear."
		return 1
	fi

	echo -n "Stopping dropbear: "

	PID="$(get_dropbear_pid)"
	if [ -z "${PID}" ]; then
		echo "not running"
		return 0
	fi

	kill "${PID}" 2> /dev/null || true
	sleep 1
	kill -0 "${PID}" 2> /dev/null && kill -9 "${PID}" 2> /dev/null || true

	PID="$(get_dropbear_pid)"
	if [ -n "${PID}" ]; then
		echo "failed"
		return 1
	fi

	clear_dropbear_pid
	echo "ok"
	return 0
}

status() {
	PID="$(get_dropbear_pid)"
	if [ -n "${PID}" ]; then
		echo "dropbear (pid ${PID}) is running"
		return 0
	else
		echo "dropbear is stopped"
		return 3
	fi
}

restart() {
	if ! is_root; then
		echo "You must be root to start or stop dropbear."
		return 1
	fi

	stop
	start
}

create_host_keys() {
	if ! is_root; then
		echo "You must be root to generate dropbear host keys."
		return 1
	fi

	[ "$1" = "--force" ] && rm -rf "${KEYDIR}"

	if is_all_host_keys_available; then
		echo "All keys present in ${KEYDIR}"
		echo "To generate new keys, use --force"
		return 0
	fi

	[ ! -d "${KEYDIR}" ] && mkdir -p -m 0700 "${KEYDIR}"
	[ ! -f "${KEYDIR}/dropbear_rsa_host_key" ]     && "${DROPBEARKEY}" -t rsa     -s 4096 -C "$(hostname)" -f "${KEYDIR}/dropbear_rsa_host_key"     && chmod 0400 "${KEYDIR}"/dropbear_rsa_host_key* 2> /dev/null     || true
	[ ! -f "${KEYDIR}/dropbear_ecdsa_host_key" ]   && "${DROPBEARKEY}" -t ecdsa   -s 521  -C "$(hostname)" -f "${KEYDIR}/dropbear_ecdsa_host_key"   && chmod 0400 "${KEYDIR}"/dropbear_ecdsa_host_key* 2> /dev/null   || true
	[ ! -f "${KEYDIR}/dropbear_ed25519_host_key" ] && "${DROPBEARKEY}" -t ed25519         -C "$(hostname)" -f "${KEYDIR}/dropbear_ed25519_host_key" && chmod 0400 "${KEYDIR}"/dropbear_ed25519_host_key* 2> /dev/null || true

	echo "done"
	return 0
}


## PARSER
case "$1" in
	start)
		start
		;;
	stop)
		stop
		;;
	restart)
		restart
		;;
	status)
		status
		;;
	create-host-keys)
		create_host_keys "$2"
		;;
	*)
		echo "Usage: $0 {start|stop|restart|status|create-host-keys}"
		exit 1
		;;
esac

exit $?
