#!/bin/sh
#
# Copyright (c) 2005 Dario Freni
#
# See COPYING for licence terms.
#
# $FreeBSD$
# $Id: customroot.sh,v 1.1.1.1 2008/03/25 19:58:15 sullrich Exp $

set -e -u

if [ -z "${LOGFILE:-}" ]; then
    echo "This script can't run standalone."
    echo "Please use launch.sh to execute it."
    exit 1
fi

CUSTOMROOT=${CUSTOMROOT:-extra/customroot}

cd ${CUSTOMROOT}

if [ $FREEBSD_VERSION -ge 8 ]; then
	tar --exclude=\.git -c -f - * | ( cd /$BASEDIR; tar xfp -)
else
	find . -not -name 'README' -not -path '*CVS*' | \
    	cpio -dump -R 0:0 -v ${BASEDIR} >> ${LOGFILE} 2>&1
fi

# Regenerate the password db if ${CUSTOMROOT}/etc/master.passwd exists
if [ -f etc/master.passwd ]; then 
    chroot ${BASEDIR} cap_mkdb /etc/master.passwd
    chroot ${BASEDIR} pwd_mkdb /etc/master.passwd
fi

# Fix permissions of ssh keys
find ${BASEDIR}/etc/ssh -name 'ssh_host*key' -exec chmod 600 {} \;

# If CUSTOMROOT_MTREE is set, fix file properties using
# $CUSTOMROOT_MTREE file.
# You can easily create your mtree file using:
# mtree -Pcp /your/customrootdir > /your/customrootmtree
# You can also edit the resulting file

if [ ! -z "${CUSTOMROOT_MTREE:-}" ]; then
    mtree -PUe -p ${BASEDIR} < ${CUSTOMROOT_MTREE}
fi

cd ${LOCALDIR}

