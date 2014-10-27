#!/bin/sh
#
# Copyright (c) 2005 Dario Freni
#
# See COPYING for licence terms.
#
# $FreeBSD$
# $Id: rootmfs.sh,v 1.1.1.1 2008/03/25 19:58:15 sullrich Exp $

set -e -u

if [ -z "${LOGFILE:-}" ]; then
    echo "This script can't run standalone."
    echo "Please use launch.sh to execute it."
    exit 1
fi

TMPFILE=$(mktemp -t rootmfs)

cp ${LOCALDIR}/extra/rootmfs/rootmfs.rc ${BASEDIR}/etc/rc.d/rootmfs
chmod 555 ${BASEDIR}/etc/rc.d/rootmfs

mtree -Pcp ${BASEDIR}/root > ${TMPFILE}
mv ${TMPFILE} ${BASEDIR}/etc/mtree/root.dist
