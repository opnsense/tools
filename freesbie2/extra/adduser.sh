#!/bin/sh
#
# Copyright (c) 2005 Dario Freni
#
# See COPYING for licence terms.
#
# $FreeBSD$
# $Id: adduser.sh,v 1.1.1.1 2008/03/25 19:58:15 sullrich Exp $

set -e -u

if [ -z "${LOGFILE:-}" ]; then
    echo "This script can't run standalone."
    echo "Please use launch.sh to execute it."
    exit 1
fi

TMPFILE=$(mktemp -t adduser)

FREESBIE_ADDUSER="${FREESBIE_ADDUSER:-freesbie}"

# If directory /home exists, move it to /usr/home and do a symlink
if [ ! -L ${BASEDIR}/home -a -d ${BASEDIR}/home ]; then
	mv ${BASEDIR}/home ${BASEDIR}/usr/home
fi

if [ ! -d ${BASEDIR}/usr/home ]; then
    mkdir -p ${BASEDIR}/usr/home
fi

if [ ! -d ${BASEDIR}/usr/home/${FREESBIE_ADDUSER} ]; then
    mkdir -p ${BASEDIR}/usr/home/${FREESBIE_ADDUSER}
fi

if [ ! -L ${BASEDIR}/home ]; then
    ln -s usr/home ${BASEDIR}/home
fi


set +e
grep -q ^${FREESBIE_ADDUSER}: ${BASEDIR}/etc/master.passwd

if [ $? -ne 0 ]; then
    chroot ${BASEDIR} pw useradd ${FREESBIE_ADDUSER} \
        -u 1000 -c "FreeSBIE User" -d "/home/${FREESBIE_ADDUSER}" \
        -g 0 -G 5 -m -s /bin/tcsh -k /usr/share/skel -w none
else
    chroot ${BASEDIR} pw usermod ${FREESBIE_ADDUSER} \
        -u 1000 -c "FreeSBIE User" -d "/home/${FREESBIE_ADDUSER}" \
        -g 0 -G 5 -m -s /bin/tcsh -k /usr/share/skel -w none
fi

chroot ${BASEDIR} pw group mod operator -m ${FREESBIE_ADDUSER}

set -e

chown -R 1000:0 ${BASEDIR}/usr/home/${FREESBIE_ADDUSER}

if [ ! -z "${NO_UNIONFS:-}" ]; then
    echo ">>> Adding init script for /home mfs"

    cp ${LOCALDIR}/extra/adduser/homemfs.rc ${BASEDIR}/etc/rc.d/homemfs
    chmod 555 ${BASEDIR}/etc/rc.d/homemfs

    echo ">>> Saving mtree structure for /home/"

    mtree -Pcp ${BASEDIR}/usr/home > ${TMPFILE}
    mv ${TMPFILE} ${BASEDIR}/etc/mtree/home.dist
fi
