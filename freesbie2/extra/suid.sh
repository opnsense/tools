#!/bin/sh
#
# Copyright (c) 2006 Matteo Riondato
#
# See COPYING for licence terms.
#
# $FreeBSD$
# $Id: suid.sh,v 1.1.1.1 2008/03/25 19:58:15 sullrich Exp $

set -e -u

if [ -z "${LOGFILE:-}" ]; then
    echo "This script can't run standalone."
    echo "Please use launch.sh to execute it."
    exit 1
fi

SUIDFILES="/sbin/ping /sbin/ping6 /sbin/shutdown"

for i in $SUIDFILES ; do
	mv ${BASEDIR}$i ${BASEDIR}/usr$i
	chroot ${BASEDIR} ln -s /usr$i $i
done

