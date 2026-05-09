#!/usr/bin/env bash

SCRIPT_DIR=$(pwd)
DROPBEAR_DIR="$(cd "${SCRIPT_DIR}/../" && pwd)"

echo "Compiling Zlib..."
. "${SCRIPT_DIR}/zlib-static-compile.sh"

cd "${DROPBEAR_DIR}"
make distclean >/dev/null 2>&1 || true

echo "Patching dropbear codebase..."
. "${SCRIPT_DIR}/modify-code.sh"

echo "Running configure..."
CFLAGS="-O2" \
	CPPFLAGS="-I${ZLIB_STATIC_DIR}/include -I${SCRIPT_DIR}" \
	LDFLAGS="${ZLIB_STATIC_DIR}/lib/libz.a" \
	LTM_CFLAGS="-I${SCRIPT_DIR} -I../src -I.. -DDROPBEAR_SERVER -DDROPBEAR_CLIENT -O2" \
	./configure --enable-static --with-zlib="${ZLIB_STATIC_DIR}" 2>&1 | tee "${SCRIPT_DIR}/configure.log"

echo "Running make..."
make AR=ar RANLIB=ranlib PROGRAMS="dropbear dbclient dropbearkey scp" 2>&1 | tee "${SCRIPT_DIR}/make.log"

echo ""
echo "Done."
echo "Find the executables dropbear, dbclient, dropbearkey, and scp in the dropbear folder."

ls -al  dropbear dbclient dropbearkey scp
-rwxrwxr-x   1 merlin   merlin    1416527 May  9 12:26 dbclient
-rwxrwxr-x   1 merlin   merlin    1536920 May  9 12:26 dropbear
-rwxrwxr-x   1 merlin   merlin    1159865 May  9 12:26 dropbearkey
-rwxrwxr-x   1 merlin   merlin     567186 May  9 12:26 scp

cd "${SCRIPT_DIR}"

#. "${SCRIPT_DIR}/dropbear-install.sh"
