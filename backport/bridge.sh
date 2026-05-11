#!/usr/bin/env bash

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

NAME=${0##*/}
DIR=$(cd "${0%/*}" 2>/dev/null || cd .; pwd)

case `uname -m` in
	i386) ${DIR}/${NAME}-386 "$@" ;;
	*) ${DIR}/${NAME}-486 "$@" ;;
esac
