#!/bin/bash

set -e

usage() {
	echo "Usage: ${0##*/} -i386 | -i486 | -auto | -multi"
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

if [ "$(id -u)" -ne 0 ]; then
	echo "This script must be run with root privileges."
	exit 1
fi

SCRIPT_DIR="$(cd "${0%/*}" 2>/dev/null || cd .; pwd)"
DROPBEAR_DIR="$(cd "${SCRIPT_DIR}/../" && pwd)"
i386_BUILD_DIR="${DROPBEAR_DIR}/bin/build/i386"
i486_BUILD_DIR="${DROPBEAR_DIR}/bin/build/i486"
i386_SUFFIX=""
i486_SUFFIX=""

TARGET_FLAG="$1"
case "${TARGET_FLAG}" in
	-auto)
		case `uname -m` in
			i386) INSTALL_i386='true' ;;
			*) INSTALL_i486='true' ;;
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
	SRC_DIR="${1}"
	if [ ! -f "${SRC_DIR}/dbclient" ] || [ ! -f "${SRC_DIR}/dropbear" ] || [ ! -f "${SRC_DIR}/dropbearkey" ] || [ ! -f "${SRC_DIR}/scp" ]; then
		echo "No dropbear binaries exist in '${SRC_DIR}'. Run 'dropbear-compile.sh ${TARGET_FLAG}' to build them before running this install script."
		exit 1
	fi
	return 0
}

install_binaries() {
	SRC_DIR="${1}"
	EXEC_SUFFIX="${2}"
	ARR=( /usr/sbin/dropbear /usr/bin/dbclient /usr/bin/dropbearkey /usr/bin/scp )
	for p in "${ARR[@]}"; do
		printf "  %s\n" "${p}${EXEC_SUFFIX}"
		install -m 0755 -o root -g root "${SRC_DIR}/$(basename "${p}")" "${p}${EXEC_SUFFIX}"
	done
}

install_bridge() {
	SRC_DIR="${1}"
	ARR=( /usr/sbin/dropbear /usr/bin/dbclient /usr/bin/dropbearkey /usr/bin/scp )
	for p in "${ARR[@]}"; do
		printf "  %s\n" "${p}"
		install -m 0755 -o root -g root "${SRC_DIR}/bridge.sh" "${p}"
	done
}

echo "Installing Binaries:"
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


# Initialize host keys
echo "Installing host keys:"
KEYDIR=/etc/dropbear
mkdir -m 0700 -p "${KEYDIR}"
ARR=( "rsa 4096" "ecdsa 521" "ed25519" )
for p in "${ARR[@]}"; do
	keytype="$(echo "${p}" | awk '{print $1}')"
	keysize="$(echo "${p}" | awk '{print $2}')"
	[ -n "${keysize}" ] && keysize_param="-s ${keysize}"
	filename="${KEYDIR}/dropbear_${keytype}_host_key"
	if [ ! -f "${filename}" ]; then
		printf "  %s\n" "${p}"
		/usr/bin/dropbearkey -t ${keytype} ${keysize_param} -C "$(hostname)" -f "${filename}"
		chmod 0400 "${filename}" || true
		chmod 0644 "${filename}.pub" || true
	fi
done


# Install init script on systems that use SysVinit
echo "Installing init.d script:"
if [ -d /etc/rc.d/init.d ] && [ -d /etc/rc.d/rc0.d ] && \
	[ -d /etc/rc.d/rc1.d ] && [ -d /etc/rc.d/rc2.d ] && \
	[ -d /etc/rc.d/rc3.d ] && [ -d /etc/rc.d/rc4.d ] && \
	[ -d /etc/rc.d/rc5.d ] && [ -d /etc/rc.d/rc6.d ]; then

	INIT_SCRIPT="/etc/rc.d/init.d/dropbear"
	printf "  %s\n" "${INIT_SCRIPT}"
	cp -f "${SCRIPT_DIR}/dropbear_initd.sh" "${INIT_SCRIPT}"
	chmod 0755 "${INIT_SCRIPT}"
	chown root:root "${INIT_SCRIPT}"

	if command -v chkconfig >/dev/null 2>&1; then
		printf "  %s\n" "chkconfig --add dropbear"
		chkconfig --add dropbear || true
		printf "  %s\n" "chkconfig dropbear on"
		chkconfig dropbear on || true
	else
		ARR=( /etc/rc.d/rc0.d/K25dropbear \
			/etc/rc.d/rc1.d/K25dropbear \
			/etc/rc.d/rc2.d/K25dropbear \
			/etc/rc.d/rc3.d/S55dropbear \
			/etc/rc.d/rc4.d/S55dropbear \
			/etc/rc.d/rc5.d/S55dropbear \
			/etc/rc.d/rc6.d/K25dropbear
		)
		for p in "${ARR[@]}"; do
			printf "  %s\n" "${p}"
			ln -sf "${INIT_SCRIPT}" "${p}"
		done
	fi
else
	echo "  SysVinit layout not detected; skipping init script installation."
fi


# Update /etc/services
if [ -e /etc/services ]; then
	echo "Updating /etc/services:"
	SERVICE_PORT_22="$(grep -E '[[:blank:]]22/tcp' /etc/services | awk 'NR==1 {print $1}')"
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
Done.


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
