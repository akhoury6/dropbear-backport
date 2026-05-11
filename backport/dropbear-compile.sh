#!/usr/bin/env bash

set -e

usage() {
	echo "Usage: ${0##*/} -386 | -486"
	echo ""
	echo "Build Dropbear for one of the supported x86 targets:"
	echo "  -386    Build for Intel 80386-compatible systems using portable crypto settings"
	echo "  -486    Build for Intel 80486/Pentium-class systems with the standard build flags"
	echo ""
	echo "Examples:"
	echo "  ${0##*/} -386"
	echo "  ${0##*/} -486"
	exit 1
}

if [ $# -ne 1 ]; then
	usage
fi

TARGET_FLAG="$1"
case "${TARGET_FLAG}" in
	-386)
		BUILD_TARGET="386"
		EXTRA_FLAGS="-m386 -DLTC_NO_BSWAP -DLTC_NO_ASM"
		BUILD_OUT_DIR="bin/build/i386"
		;;
	-486)
		BUILD_TARGET="486"
		EXTRA_FLAGS=""
		BUILD_OUT_DIR="bin/build/i486"
		;;
	*)
		usage
		;;
esac

if [ -f "${BUILD_OUT_DIR}/dbclient" ] || \
   [ -f "${BUILD_OUT_DIR}/dropbear" ] || \
   [ -f "${BUILD_OUT_DIR}/dropbearkey" ] || \
   [ -f "${BUILD_OUT_DIR}/scp" ]; then
   echo "Binaries already exist in '${BUILD_OUT_DIR}'. Delete them before compiling again."
   exit 1
fi

echo "Selected build target: ${BUILD_TARGET}"

SCRIPT_DIR="$(cd "${0%/*}" 2>/dev/null || cd .; pwd)"
DROPBEAR_DIR="$(cd "${SCRIPT_DIR}/../" && pwd)"

echo "Compiling Zlib..."
. "${SCRIPT_DIR}/zlib-static-compile.sh" "${TARGET_FLAG}"

cd "${DROPBEAR_DIR}"
make distclean >/dev/null 2>&1 || true

echo "Patching dropbear codebase..."
. "${SCRIPT_DIR}/backport-code-patch.sh"

echo "Running configure..."
CFLAGS="-O2 ${EXTRA_FLAGS}" \
CPPFLAGS="-I${ZLIB_STATIC_DIR}/include -I${SCRIPT_DIR}" \
LDFLAGS="-static ${ZLIB_STATIC_DIR}/lib/libz.a" \
LTM_CFLAGS="-I${SCRIPT_DIR} -I../src -I.. -DDROPBEAR_SERVER -DDROPBEAR_CLIENT -O2 ${EXTRA_FLAGS}" \
./configure --enable-static --with-zlib="${ZLIB_STATIC_DIR}" 2>&1 | tee "${SCRIPT_DIR}/configure.log"

echo "Running make..."
make AR=ar RANLIB=ranlib PROGRAMS="dropbear dbclient dropbearkey scp" 2>&1 | tee "${SCRIPT_DIR}/make.log"

mkdir -p "${BUILD_OUT_DIR}"

mv dbclient "${BUILD_OUT_DIR}/"
mv dropbear "${BUILD_OUT_DIR}/"
mv dropbearkey "${BUILD_OUT_DIR}/"
mv scp "${BUILD_OUT_DIR}/"

chmod 0755 "${BUILD_OUT_DIR}/*"

echo ""
echo "Done."
echo "Find the executables dropbear, dbclient, dropbearkey, and scp in the '${BUILD_OUT_DIR}/' folder."
echo ""
echo "There is an installer that works with RedHat 5.2, which creates an init.d script"
echo ""

cd "${SCRIPT_DIR}"

#. "${SCRIPT_DIR}/dropbear-install.sh"
