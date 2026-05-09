#!/usr/bin/env bash

SCRIPT_DIR=$(pwd)
ZLIB_VERSION="1.3.2"
ZLIB_TARFILE="${SCRIPT_DIR}/zlib-${ZLIB_VERSION}.tar.gz"
ZLIB_DIR="${SCRIPT_DIR}/zlib-${ZLIB_VERSION}"
ZLIB_STATIC_DIR="${ZLIB_DIR}-static"

if [ -f "${ZLIB_STATIC_DIR}/lib/libz.a" ]; then
	echo "zlib already compiled. Skipping."
else
	[ -d "${ZLIB_DIR}" ] && rm -rf "${ZLIB_DIR}"
	[ -d "${ZLIB_STATIC_DIR}" ] && rm -rf "${ZLIB_STATIC_DIR}"

	tar -zxpf "${ZLIB_TARFILE}"
	cd "${ZLIB_DIR}"

	perl -0pi -e 's@#if !defined\(Z_U8\) && !defined\(Z_SOLO\) && defined\(STDC\)\n.*?\n#endif@#if !defined(Z_U8) && !defined(Z_SOLO) && defined(STDC)\n#  define Z_U8 unsigned long\n#endif@s' "${ZLIB_DIR}/zutil.h"

	CC=gcc \
		CFLAGS="-O2" \
		./configure --static "--prefix=${ZLIB_STATIC_DIR}"

	make libz.a
	make install

	cd "${SCRIPT_DIR}"
fi

export ZLIB_STATIC_DIR
