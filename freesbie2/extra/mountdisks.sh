#!/bin/sh
#
# Copyright (c) Matteo Riondato
#
# See COPYING for licence terms.
#
# $Id: mountdisks.sh,v 1.1.1.1 2008/03/25 19:58:15 sullrich Exp $
# 

set -e -u

if [ -z "${LOGFILE:-}" ]; then
    echo "This script can't run standalone."
    echo "Please use launch.sh to execute it."
    exit 1
fi

mkdir -p $BASEDIR/mnt $BASEDIR/etc/rc.d/ $BASEDIR/usr/local/sbin/

cp extra/mountdisks/mountdisks.sh $BASEDIR/usr/local/sbin/mountdisks
chmod 555 $BASEDIR/usr/local/sbin/mountdisks

cp extra/mountdisks/mountdisksrc.sh $BASEDIR/etc/rc.d/mountdisks
chmod 555 $BASEDIR/etc/rc.d/mountdisks

for fs in dos ext2fs ntfs ufs reiser;  do
    for i in 1 2 3 4 5 6 7 8; do
	mkdir -p $BASEDIR/mnt/$fs.$i
    done
done

