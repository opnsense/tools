#!/bin/sh
#
# Copyright (c) 2005 Dario Freni
#
# See COPYING for licence terms.
#
# $FreeBSD$
# $Id: comconsole.sh,v 1.1.1.1 2008/03/25 19:58:15 sullrich Exp $
#
# Enable serial console at boot, in addition to video console
# If you want to use only serial console, define the
# SERIAL_ONLY variable somewhere

set -e -u

if [ -z "${LOGFILE:-}" ]; then
    echo "This script can't run standalone."
    echo "Please use launch.sh to execute it."
    exit 1
fi

TMPFILE=$(mktemp -t comconsole)

# Remove any existing line regarding console in loader.conf
touch ${BASEDIR}/boot/loader.conf
set +e # grep exit status depends on actual content of loader.conf
grep -v '^console=' ${BASEDIR}/boot/loader.conf > ${TMPFILE};
set -e
mv ${TMPFILE} ${BASEDIR}/boot/loader.conf 

# Remove any existing line regarding console in ttys
set +e # grep exit status depends on actual content of ttys
grep -v '^ttyd0' ${BASEDIR}/etc/ttys > ${TMPFILE};
set -e
mv ${TMPFILE} ${BASEDIR}/etc/ttys

printf "ttyd0\t\"/usr/libexec/getty std.9600\"\tdialup\ton\tsecure\n" >> ${BASEDIR}/etc/ttys

if [ -z "${SERIAL_ONLY:-}" ]; then
	echo "-D" > ${BASEDIR}/boot.config
	echo 'console="vidconsole, comconsole"' >> ${BASEDIR}/boot/loader.conf
else
	echo "-h" > ${BASEDIR}/boot.config
	echo 'console="comconsole"' >> ${BASEDIR}/boot/loader.conf
fi

return 0
