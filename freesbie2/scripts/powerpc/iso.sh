#!/bin/sh
#
# Copyright (c) 2005 Dario Freni
#
# See COPYING for licence terms.
#
# $FreeBSD$
# $Id: iso.sh,v 1.1.1.1 2008/03/25 19:58:16 sullrich Exp $

if [ -z "${LOGFILE:-}" ]; then
    echo "This script can't run standalone."
    echo "Please use launch.sh to execute it."
    exit 1
fi

FREESBIE_LABEL=${FREESBIE_LABEL:-"FreeSBIE"}

echo "#### Building bootable ISO image for ${ARCH} ####"

# This part was taken from the mkisoimages.sh scripts under
# /usr/src/release/${ARCH}/
type mkisofs 2>&1 | grep " is " >/dev/null
if [ $? -ne 0 ]; then
    echo The cdrtools port is not installed.  Trying to get it now.
    if [ -f /usr/ports/sysutils/cdrtools/Makefile ]; then
	cd /usr/ports/sysutils/cdrtools && ARCH="$(uname -p)" make install BATCH=yes && make clean
    else
	if ! pkg_add -r cdrtools; then
	    echo "Could not get it via pkg_add - please go install this"
	    echo "from the ports collection and run this script again."
	    exit 2
	fi
    fi
fi


echo "Saving mtree structure..."
mtree -Pcp ${CLONEDIR} | bzip2 -9 > root.dist.bz2
mkdir -p ${CLONEDIR}/dist
mv root.dist.bz2 ${CLONEDIR}/dist/

echo "/dev/iso9660/${FREESBIE_LABEL} / cd9660 rw 0 0" > ${CLONEDIR}/etc/fstab

cd ${CLONEDIR}
cp ${SRCDIR}/release/powerpc/boot.tbxi boot

# Detect if mkisofs support -L or -posix-L
if mkisofs --help 2>&1 | grep -q -- -posix-L; then
	LOPT="-posix-L"
else
	LOPT="-L"
fi

echo "Running mkisofs..."

mkisofs -hfs-bless boot -map ${SRCDIR}/release/powerpc/hfs.map -r -hfs -part -no-desktop -hfs-volid ${FREESBIE_LABEL} -V ${FREESBIE_LABEL} -l -J ${LOPT} -o $ISOPATH . >> ${LOGFILE} 2>&1

echo "ISO created:"

ls -lh ${ISOPATH}

cd ${LOCALDIR}
