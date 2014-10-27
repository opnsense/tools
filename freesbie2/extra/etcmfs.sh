#!/bin/sh
#
# Copyright (c) 2005 Dario Freni
#
# See COPYING for licence terms.
#
# $FreeBSD$
# $Id: etcmfs.sh,v 1.1.1.1 2008/03/25 19:58:15 sullrich Exp $

set -e -u

if [ -z "${LOGFILE:-}" ]; then
    echo "This script can't run standalone."
    echo "Please use launch.sh to execute it."
    exit 1
fi

TMPFILE=$(mktemp -t etcmfs)

cp ${LOCALDIR}/extra/etcmfs/etcmfs.rc ${BASEDIR}/etc/rc.d/etcmfs
chmod 555 ${BASEDIR}/etc/rc.d/etcmfs

mtree -Pcp ${BASEDIR}/etc > ${TMPFILE}
mv ${TMPFILE} ${BASEDIR}/etc/mtree/etc.dist

if [ -d ${BASEDIR}/usr/local/etc ]; then
    mtree -Pcp ${BASEDIR}/usr/local/etc > ${TMPFILE}
    mv ${TMPFILE} ${BASEDIR}/etc/mtree/localetc.dist
fi