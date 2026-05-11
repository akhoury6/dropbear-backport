#!/usr/bin/env bash

set -e

usage() {
	echo "Usage: ${0##*/} -386 | -486"
	echo ""
	echo "Install dropbear:"
	echo "  -386    Install the i386 binaries and the init.d script"
	echo "  -486    Install the i486/i586/i686 binaries and the init.d script"
	echo ""
	echo "Examples:"
	echo "  ${0##*/} -386"
	echo "  ${0##*/} -486"
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

TARGET_FLAG="$1"
case "${TARGET_FLAG}" in
	-386)
		BUILD_OUT_DIR="${DROPBEAR_DIR}/bin/build/i386"
		;;
	-486)
		BUILD_OUT_DIR="${DROPBEAR_DIR}/bin/build/i486"
		;;
	*)
		usage
		exit 1
		;;
esac

if [ ! -f "${BUILD_OUT_DIR}/dbclient" ] || [ ! -f "${BUILD_OUT_DIR}/dropbear" ] || \
   [ ! -f "${BUILD_OUT_DIR}/dropbearkey" ] || [ ! -f "${BUILD_OUT_DIR}/scp" ]; then
   echo "No dropbear binaries exist in '${BUILD_OUT_DIR}'. Run 'dropbear-compile.sh ${TARGET_FLAG}' to build them before running this install script."
   exit 1
fi

# Install Binaries to their locations
install -m 0755 -o root -g root "${BUILD_OUT_DIR}/dropbear" /usr/sbin/dropbear
install -m 0755 -o root -g root "${BUILD_OUT_DIR}/dbclient" /usr/bin/dbclient
install -m 0755 -o root -g root "${BUILD_OUT_DIR}/dropbearkey" /usr/bin/dropbearkey
SCP_BIN="$([ -e /usr/bin/scp ] && echo 'dbscp' || echo 'scp')"
install -m 0755 -o root -g root "${BUILD_OUT_DIR}/scp" /usr/bin/${SCP_BIN}

# Create .ssh folder for users
if [ -d /etc/skel ]; then
	mkdir -p /etc/skel/.ssh
	chmod 0700 /etc/skel/.ssh
fi

# Initialize host keys
mkdir -p /etc/dropbear
chmod 0700 /etc/dropbear
[ ! -f /etc/dropbear/dropbear_rsa_host_key ] && /usr/bin/dropbearkey -t rsa -s 4096 -f /etc/dropbear/dropbear_rsa_host_key
[ ! -f /etc/dropbear/dropbear_ecdsa_host_key ] && /usr/bin/dropbearkey -t ecdsa -s 521 -f /etc/dropbear/dropbear_ecdsa_host_key
[ ! -f /etc/dropbear/dropbear_ed25519_host_key ] && /usr/bin/dropbearkey -t ed25519 -f /etc/dropbear/dropbear_ed25519_host_key
chmod 0400 /etc/dropbear/dropbear_*_host_key /etc/dropbear/dropbear_*_host_key.pub 2> /dev/null || true

# Install init script on systems that use SysVinit
if [ -d /etc/rc.d/init.d ] && [ -d /etc/rc.d/rc0.d ] && \
	[ -d /etc/rc.d/rc1.d ] && [ -d /etc/rc.d/rc2.d ] && \
	[ -d /etc/rc.d/rc3.d ] && [ -d /etc/rc.d/rc4.d ] && \
	[ -d /etc/rc.d/rc5.d ] && [ -d /etc/rc.d/rc6.d ]; then

	INIT_SCRIPT="/etc/rc.d/init.d/dropbear"
	cp -f "${SCRIPT_DIR}/dropbear_initd.sh" "${INIT_SCRIPT}"
	chmod 0755 "${INIT_SCRIPT}"
	chown root:root "${INIT_SCRIPT}"

	touch /var/run/dropbear.pid
	chmod 0644 /var/run/dropbear.pid
	chown root:root /var/run/dropbear.pid

	if command -v chkconfig >/dev/null 2>&1; then
		chkconfig --add dropbear || true
		chkconfig dropbear on || true
	else
		ln -sf "${INIT_SCRIPT}" /etc/rc.d/rc0.d/K25dropbear
		ln -sf "${INIT_SCRIPT}" /etc/rc.d/rc1.d/K25dropbear
		ln -sf "${INIT_SCRIPT}" /etc/rc.d/rc2.d/K25dropbear
		ln -sf "${INIT_SCRIPT}" /etc/rc.d/rc3.d/S55dropbear
		ln -sf "${INIT_SCRIPT}" /etc/rc.d/rc4.d/S55dropbear
		ln -sf "${INIT_SCRIPT}" /etc/rc.d/rc5.d/S55dropbear
		ln -sf "${INIT_SCRIPT}" /etc/rc.d/rc6.d/K25dropbear
	fi
else
	echo "SysVinit layout not detected; skipping init script installation."
fi

# Update /etc/services
if [ -e /etc/services ]; then
	SERVICE_PORT_22="$(grep -E '[[:blank:]]22/tcp' /etc/services | awk 'NR==1 {print $1}')"
	if [ -z "${SERVICE_PORT_22}" ]; then
		perl -pi -e 's/^([^#]*22\/tcp)/#$1/' /etc/services
		if grep -qE '[[:blank:]]21/tcp' /etc/services; then
			perl -0pi -e 's/^([^#].*\b21\/tcp\b.*)$/$1\nssh\t\t22\/tcp/m' /etc/services
		else
			printf '\nssh\t\t22/tcp\n' >> /etc/services
		fi
		echo "Added ssh 22/tcp to /etc/services"
	elif [ "${SERVICE_PORT_22}" != "ssh" ]; then
		echo "The '${SERVICE_PORT_22}' service is configured on port 22 in /etc/services."
		echo "Please move that service to a different port, or change dropbear's init.d script to use a different port."
		echo "You will need to update /etc/services manually after installation."
	else
		echo "Port 22 is already assigned to ssh in /etc/services. Skipping."
	fi
fi

if [ -f /etc/rc.d/init.d/dropbear ]; then
	cat << EOF
Installed:
  /usr/sbin/dropbear
  /usr/bin/dbclient
  /usr/bin/dropbearkey
  /usr/bin/${SCP_BIN}

$([ -d /etc/skel/.ssh ] && printf "  /etc/skel/.ssh\n\n")
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
