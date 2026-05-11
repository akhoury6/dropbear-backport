set -e

usage() {
	echo "Usage: ${0##*/} -386 | -486"
	echo ""
	echo "Build a static zlib for one of the supported x86 targets:"
	echo "  -386    Build for Intel 80386-compatible systems using -m386"
	echo "  -486    Build for Intel 80486/Pentium-class systems with the standard build flags"
	echo ""
	echo "This script produces a target-specific static zlib directory so 386 and 486"
	echo "builds do not accidentally reuse the wrong libz.a."
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
		ZLIB_TARGET="386"
		ZLIB_CFLAGS="-O2 -m386"
		ZLIB_STATIC_DIR="${ZLIB_DIR}-static-386"
		;;
	-486)
		ZLIB_TARGET="486"
		ZLIB_CFLAGS="-O2"
		ZLIB_STATIC_DIR="${ZLIB_DIR}-static-486"
		;;
	*)
		usage
		;;
esac

SCRIPT_DIR="$(cd "${0%/*}" 2>/dev/null || cd .; pwd)"
ZLIB_VERSION="1.3.2"
ZLIB_TARFILE="${SCRIPT_DIR}/zlib-${ZLIB_VERSION}.tar.gz"
ZLIB_DIR="${SCRIPT_DIR}/zlib-${ZLIB_VERSION}"

echo "Selected zlib build target: ${ZLIB_TARGET}"

if [ -f "${ZLIB_STATIC_DIR}/lib/libz.a" ]; then
	echo "zlib already compiled for ${ZLIB_TARGET}. Skipping."
else
	[ -d "${ZLIB_DIR}" ] && rm -rf "${ZLIB_DIR}"
	[ -d "${ZLIB_STATIC_DIR}" ] && rm -rf "${ZLIB_STATIC_DIR}"

	tar -zxpf "${ZLIB_TARFILE}"
	cd "${ZLIB_DIR}"

	perl -0pi -e 's@#if !defined\(Z_U8\) && !defined\(Z_SOLO\) && defined\(STDC\)\n.*?\n#endif@#if !defined(Z_U8) && !defined(Z_SOLO) && defined(STDC)\n#  define Z_U8 unsigned long\n#endif@s' "${ZLIB_DIR}/zutil.h"

	CC=gcc \
		CFLAGS="${ZLIB_CFLAGS}" \
		./configure --static "--prefix=${ZLIB_STATIC_DIR}"

	make libz.a
	make install

	cd "${SCRIPT_DIR}"
fi

export ZLIB_STATIC_DIR
