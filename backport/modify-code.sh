#!/usr/bin/env bash
##
# All of the changes here are made to be idempotent.
##

# Disable post-quantum key exchange features because the target compiler/platform
# is too old to build sntrup761/mlkem sources cleanly.
cat > localoptions.h <<'EOF'
#define DROPBEAR_SNTRUP761 0
#define DROPBEAR_MLKEM768 0
#define DROPBEAR_KEX_PQHYBRID 0
EOF

# Remove post-quantum object files from the build list because this Dropbear version still
# compiles them unconditionally even when disabled in localoptions.h.
perl -0pi -e '
s/\\\n\t\tkex-x25519\.o kex-dh\.o kex-ecdh\.o kex-pqhybrid\.o \\\n\t\tsntrup761\.o mlkem768\.o/\\\n\t\tkex-x25519.o kex-dh.o kex-ecdh.o/s
' Makefile.in

# Name an anonymous union in libtomcrypt for compatibility with older compilers
# that reject or mishandle unnamed unions in this context.
perl -0pi -e 's/^(\s*)union \{/${1}union prng_union {/m' libtomcrypt/src/headers/tomcrypt_prng.h

# Disable the libtommath coverage target because older make implementations
# choke on this target-specific variable assignment syntax.
perl -0pi -e '
s/^coverage: LIBNAME:=-Wl,--whole-archive \$\(LIBNAME\)  -Wl,--no-whole-archive$/# coverage target disabled for old make compatibility/m
' libtommath/Makefile.in

# Move libtommath include handling from CFLAGS to CPPFLAGS and allow externally
# supplied preprocessor include paths. This lets the build pick up backport
# headers and other compatibility includes cleanly.
perl -0pi -e '
s/CFLAGS \+= -I\$\(srcdir\) -I\.\.\/libtomcrypt\/src\/headers\/ -I\$\(srcdir\)\/\.\.\/libtomcrypt\/src\/headers\/ -I\.\.\/ -I\$\(srcdir\)\/\.\.\/src\nCFLAGS \+= -Wno-deprecated\nCFLAGS \+= \$\(CPPFLAGS\)/CPPFLAGS += -I\$\(srcdir\) -I..\/libtomcrypt\/src\/headers\/ -I\$\(srcdir\)\/..\/libtomcrypt\/src\/headers\/ -I..\/ -I\$\(srcdir\)\/..\/src\nCPPFLAGS += \$\(EXTRA_CPPFLAGS\)/s;
s/LTM_CFLAGS \+= \@DROPBEAR_LTM_CFLAGS\@/LTM_CFLAGS = \$\(CPPFLAGS\) \@DROPBEAR_LTM_CFLAGS\@/s;
' libtommath/Makefile.in

# Make object compilation create the output directory explicitly instead of using
# an order-only prerequisite, for compatibility with older make behavior.
perl -0pi -e '
s/\$\(OBJ_DIR\)\/%\.o: \$\(srcdir\)\/%\.c \$\(HEADERS\) \| \$\(OBJ_DIR\)\n\t\$\(CC\) \$\(CFLAGS\) \$\(CPPFLAGS\) \$< -o \$@ -c/\$\(OBJ_DIR\)\/%\.o: \$\(srcdir\)\/%\.c \$\(HEADERS\)\n\t\@mkdir -p \$\(OBJ_DIR\)\n\t\$\(CC\) \$\(CFLAGS\) \$\(CPPFLAGS\) \$< -o \$@ -c/s
' Makefile.in

# Replace suseconds_t with long because this older libc/header set does not
# provide suseconds_t, causing loginrec.h to fail to parse.
perl -0pi -e '
s/\bsuseconds_t\b/long/g
' src/loginrec.h

# Provide fallback SHUT_RD/SHUT_WR/SHUT_RDWR definitions because the old system
# headers do not define these socket shutdown constants.
perl -0pi -e '
s@(#include <sys/socket.h>\n)(?!#ifndef SHUT_RD\n#define SHUT_RD 0\n#endif\n#ifndef SHUT_WR\n#define SHUT_WR 1\n#endif\n#ifndef SHUT_RDWR\n#define SHUT_RDWR 2\n#endif\n)@$1#ifndef SHUT_RD\n#define SHUT_RD 0\n#endif\n#ifndef SHUT_WR\n#define SHUT_WR 1\n#endif\n#ifndef SHUT_RDWR\n#define SHUT_RDWR 2\n#endif\n@s
' src/includes.h

# Replace 'mkdir -pv' with plain 'mkdir -p' for compatibility with older mkdir implementations.
perl -0pi -e 's/\bmkdir -pv\b/mkdir -p/g' configure configure.ac

# Rewrite C99-style mixed declarations in svr_switch_user() to C89-style declarations for old compilers.
# Insert ret/rc at the start of the root-only block, then rewrite the mixed declarations into assignments.
perl -0pi -e '
s@if \(getuid\(\) == 0\) \{\n(?!\t\tint ret;\n\t\tint rc;\n)@if (getuid() == 0) {\n\t\tint ret;\n\t\tint rc;\n@s;
s@\t\tint ret = utmp_gid\(&svr_ses\.utmp_gid\);@\t\tret = utmp_gid(&svr_ses.utmp_gid);@g;
s@\t\t\tint rc = setresgid\(-1, -1, svr_ses\.utmp_gid\);@\t\t\trc = setresgid(-1, -1, svr_ses.utmp_gid);@g;
' src/svr-auth.c

# Move C99-style local declarations in svr_auth_pubkey() to the top of the function for old C compiler compatibility.
perl -0pi -e '
s@(\tstruct PubKeyOptions \*pubkey_options = NULL;\n)(?!\tint status;\n\tunsigned int free_query_limit;\n\tint incrfail;\n)@\1\tint status;\n\tunsigned int free_query_limit;\n\tint incrfail;\n@s;
s@\t\tint status = checkpubkey\(keyalgo, keyalgolen, keyblob, keybloblen, &pubkey_options\);\n@\t\tstatus = checkpubkey(keyalgo, keyalgolen, keyblob, keybloblen, &pubkey_options);\n@s;
s@\t\tunsigned int free_query_limit = 0;\n\t\t\tMAX\(0, \(int\)svr_opts\.maxauthtries - MAX_PUBKEY_QUERIES\);\n\t\tint incrfail = ses\.authstate\.serv_pubkey_query_count > free_query_limit;\n@\t\tfree_query_limit = 0;\n\t\t\tMAX(0, (int)svr_opts.maxauthtries - MAX_PUBKEY_QUERIES);\n\t\tincrfail = ses.authstate.serv_pubkey_query_count > free_query_limit;\n@s
' src/svr-authpubkey.c

# Move tlocal()'s late dest declaration to the top of the function for C89 compiler compatibility.
perl -0pi -e '
s@(\tchar \*bp, \*host, \*src, \*suser;\n)(?!\tchar \*dest;\n)@\1\tchar *dest;\n@s;
s@\n\t\tchar \*dest = \*\(argv \+ argc - 1\);@\n\t\tdest = *(argv + argc - 1);@s
' src/scp.c

# Define __func__ for old compilers that do not provide it.
perl -0pi -e '
s@(#include <sys/un.h>\n)(?!#ifndef __func__\n#define __func__ "__func__"\n#endif\n)@$1#ifndef __func__\n#define __func__ "__func__"\n#endif\n@s
' src/includes.h

# Make PTY owner/mode setup non-fatal on legacy systems where chown/chmod on tty devices can fail with EPERM.
perl -0pi -e '
s/\bdropbear_exit\("chown\(%\.100s, %u, %u\) failed: %\.100s",/dropbear_log(LOG_ERR,\n\t\t\t\t\t"chown(%.100s, %u, %u) failed: %.100s",/g;
s/\bdropbear_exit\("chmod\(%\.100s, 0%o\) failed: %\.100s",/dropbear_log(LOG_ERR,\n\t\t\t\t\t"chmod(%.100s, 0%o) failed: %.100s",/g;
' src/sshpty.c
