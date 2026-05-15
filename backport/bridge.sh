#!/bin/sh

# Optional script for a dual 386/486-arch installation.
#
# This script lets you run a command like 'dropbear',
# and then automatically chooses the correct executable
# for your system's architecture.
#
# Instructions:
#
# Place the 386-compiled binary at /usr/sbin/dropbear-386
# Place the 486-compiled binary at /usr/sbin/dropbear-486
# Place this script at /usr/sbin/dropbear
#
# Now when running /usr/sbin/dropbear, this script will
# detect which architecture is being used and run the
# corresponding executable.
#
# Repeat for dbclient, dropbearkey, and scp
#

### These may or may not be compatible with your version of bash.
### Leaving them here, commented, in case someone needs them.
# NAME=${0##*/}
# DIR=$(cd "${0%/*}" 2>/dev/null || cd .; pwd)

NAME=`basename "$0"`
DIR_RAW=`dirname "$0"`
DIR=`cd "${DIR_RAW}" 2>/dev/null && pwd`

case `uname -m` in
	i386) exec "${DIR}/${NAME}-386" "$@" ;;
	*) exec "${DIR}/${NAME}-486" "$@" ;;
esac
