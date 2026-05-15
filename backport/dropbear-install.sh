#!/bin/bash

set -e

usage() {
	echo "Usage: `basename $0` -i386 | -i486 | -auto | -multi"
	echo ""
	echo "Install dropbear:"
	echo "  -i386    Install the i386 binaries and the init.d script"
	echo "  -i486    Install the i486/i586/i686 binaries and the init.d script"
	echo "  -auto    Automatically detect the correct architecture for the system"
	echo "  -multi   Install both, and auto-select which one to run on this system at runtime"
	echo ""
	exit 1
}

if [ $# -ne 1 ]; then
	usage
fi

if [ "${USER}" != "root" ]; then
	echo "This script must be run with root privileges."
	exit 1
fi

#SCRIPT_DIR="$(cd "${0%/*}" 2>/dev/null || cd .; pwd)"
SCRIPT_DIR_RAW=`dirname "$0"`
SCRIPT_DIR=`cd "${SCRIPT_DIR_RAW}" 2>/dev/null && pwd`
DROPBEAR_DIR=`cd "${SCRIPT_DIR}/.." && pwd`
i386_BUILD_DIR="${DROPBEAR_DIR}/bin/build/i386"
i486_BUILD_DIR="${DROPBEAR_DIR}/bin/build/i486"
i386_SUFFIX=""
i486_SUFFIX=""

TARGET_FLAG="$1"
case "${TARGET_FLAG}" in
	-auto)
		ARCH=`uname -m`
		case "${ARCH}" in
			i386) INSTALL_i386='true' ;;
			i486|i586|i686) INSTALL_i486='true' ;;
			*) echo "The ${ARCH} architecture is not supported by this script."; exit 1;;
		esac
		;;
	-i386)
		INSTALL_i386='true'
		;;
	-i486)
		INSTALL_i486='true'
		;;
	-multi)
		INSTALL_i386='true'
		INSTALL_i486='true'
		i386_SUFFIX="-386"
		i486_SUFFIX="-486"
		INSTALL_BRIDGE='true'
		;;
	*)
		usage
		exit 1
		;;
esac


# Install Binaries to their locations
does_build_exist() {
	echo "Verifying Source:"
	local SRC_DIR MISSING_BINARY
	SRC_DIR="${1}"
	MISSING_BINARY="false"
	[ ! -f "${SRC_DIR}/dbclient" ] && MISSING_BINARY="true"
	[ ! -f "${SRC_DIR}/dropbear" ] && MISSING_BINARY="true"
	[ ! -f "${SRC_DIR}/dropbearkey" ] && MISSING_BINARY="true"
	[ ! -f "${SRC_DIR}/scp" ] && MISSING_BINARY="true"
	if [ "${MISSING_BINARY}" = "true" ]; then
		echo "  No dropbear binaries exist in '${SRC_DIR}'. Run 'dropbear-compile.sh ${TARGET_FLAG}' to build them before running this install script."
		exit 1
	fi
	echo "  Binaries found at ${SRC_DIR}"
	return 0
}

install_binaries() {
	echo "Installing Binaries:"
	local SRC_DIR EXEC_SUFFIX TARGETS target
	SRC_DIR="${1}"
	EXEC_SUFFIX="${2}"
	TARGETS="/usr/sbin/dropbear /usr/bin/dbclient /usr/bin/dropbearkey /usr/bin/scp"
	for target in $TARGETS; do
		printf "  %s\n" "${target}${EXEC_SUFFIX}"
		cp -f "${SRC_DIR}/`basename $target`" "${target}${EXEC_SUFFIX}"
		chmod 0755 "${target}${EXEC_SUFFIX}"
		chown root "${target}${EXEC_SUFFIX}"
		chgrp root "${target}${EXEC_SUFFIX}"
	done
}

install_bridge() {
	echo "Installing Bridge:"
	local SRC_DIR TARGETS target
	SRC_DIR="${1}"
	TARGETS="/usr/sbin/dropbear /usr/bin/dbclient /usr/bin/dropbearkey /usr/bin/scp"
	for target in $TARGETS; do
		printf "  %s\n" "${target}"
		cp -f "${SRC_DIR}/bridge.sh" "${target}"
		chmod 0755 "${target}"
		chown root "${target}"
		chgrp root "${target}"
	done
}

[ -n "${INSTALL_i386}" ] && does_build_exist "${i386_BUILD_DIR}"
[ -n "${INSTALL_i486}" ] && does_build_exist "${i486_BUILD_DIR}"
[ -n "${INSTALL_i386}" ] && install_binaries "${i386_BUILD_DIR}" "${i386_SUFFIX}"
[ -n "${INSTALL_i486}" ] && install_binaries "${i486_BUILD_DIR}" "${i486_SUFFIX}"
[ -n "${INSTALL_BRIDGE}" ] && install_bridge "${SCRIPT_DIR}"


# Create .ssh folder for users
echo "Installing .ssh folder:"
if [ -d /etc/skel ]; then
	printf "  %s\n" "/etc/skel/.ssh"
	mkdir -p /etc/skel/.ssh
	chmod 0700 /etc/skel/.ssh
fi

# Install init script on systems that use SysVinit
INIT_SCRIPT="/etc/rc.d/init.d/dropbear"
echo "Installing init.d script:"
if [ -d /etc/rc.d/init.d ] && [ -d /etc/rc.d/rc0.d ] &&
	[ -d /etc/rc.d/rc1.d ] && [ -d /etc/rc.d/rc2.d ] &&
	[ -d /etc/rc.d/rc3.d ] && [ -d /etc/rc.d/rc4.d ] &&
	[ -d /etc/rc.d/rc5.d ] && [ -d /etc/rc.d/rc6.d ]; then

	printf "  %s\n" "${INIT_SCRIPT}"
	cp -f "${SCRIPT_DIR}/dropbear-initd.sh" "${INIT_SCRIPT}"
	chmod 0755 "${INIT_SCRIPT}"
	chown root "${INIT_SCRIPT}"
	chgrp root "${INIT_SCRIPT}"

	if type chkconfig >/dev/null 2>&1; then
		printf "  %s\n" "chkconfig --add dropbear"
		chkconfig --add dropbear || true
		printf "  %s\n" "chkconfig dropbear on"
		chkconfig dropbear on || true
	else
		RUNLEVEL_TARGETS=`cat << 'LIST'
/etc/rc.d/rc0.d/K25dropbear
/etc/rc.d/rc1.d/K25dropbear
/etc/rc.d/rc2.d/K25dropbear
/etc/rc.d/rc3.d/S55dropbear
/etc/rc.d/rc4.d/S55dropbear
/etc/rc.d/rc5.d/S55dropbear
/etc/rc.d/rc6.d/K25dropbear
LIST
`
		for target in $RUNLEVEL_TARGETS; do
			printf "  %s\n" "${target}"
			ln -sf "${INIT_SCRIPT}" "${target}"
		done
	fi
else
	echo "  SysVinit layout not detected; skipping init script installation."
fi


# Initialize host keys
echo "Installing host keys:"
if [ -x "${INIT_SCRIPT}" ]; then
	"${INIT_SCRIPT}" create-host-keys
else
	"Init script not executable. Skipping."
fi

# Update /etc/services
if [ -e /etc/services ]; then
	echo "Updating /etc/services:"
	SERVICE_PORT_22=`grep '^[[:blank:]]*[^#]*[[:blank:]]22/tcp' /etc/services | awk '{print $1}'`
	if [ -z "${SERVICE_PORT_22}" ]; then
		perl -pi -e 's/^([^#]*22\/tcp)/#$1/' /etc/services
		if grep -qE '[[:blank:]]21/tcp' /etc/services; then
			perl -0pi -e 's/^([^#].*\b21\/tcp\b.*)$/$1\nssh\t\t22\/tcp/m' /etc/services
		else
			printf '\nssh\t\t22/tcp\n' >> /etc/services
		fi
		echo "  Added ssh 22/tcp to /etc/services"
	elif [ "${SERVICE_PORT_22}" != "ssh" ]; then
		echo "  The '${SERVICE_PORT_22}' service is configured on port 22 in /etc/services."
		echo "  Please move that service to a different port, or change dropbear's init.d script to use a different port."
		echo "  You will need to update /etc/services manually after installation."
	else
		echo "  Port 22 is already assigned to ssh in /etc/services. Skipping."
	fi
fi


# Finish Up
if [ -f /etc/rc.d/init.d/dropbear ]; then
	cat << EOF
Installation Complete.
========================================
Init script:
  /etc/rc.d/init.d/dropbear

To start the ssh daemon now:
  /etc/rc.d/init.d/dropbear start

To check status:
  /etc/rc.d/init.d/dropbear status

To disable:
  chkconfig dropbear off
EOF
fi
