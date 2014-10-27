#!/bin/sh
#
# Copyright (c) 2006 Matteo Riondato
#
# See COPYING for licence terms.
#
# $Id: backup.sh,v 1.1.1.1 2008/03/25 19:58:15 sullrich Exp $

set -e -u

if [ -z "${LOGFILE:-}" ]; then
	echo "This script can't run standalone."
	echo "Please use launch.sh to execute it."
	exit 1
fi

# we use ".sh" in the destination so that the script will be sourced
# in the "main" shell
cp extra/backup/restorebackup.rc $BASEDIR/etc/rc.d/restorebackup
chmod 555 $BASEDIR/etc/rc.d/restorebackup
mkdir -p $BASEDIR/usr/local/bin
cp extra/backup/restorebackup.sh $BASEDIR/usr/local/sbin/restorebackup
chmod 555 $BASEDIR/usr/local/sbin/restorebackup
cp extra/backup/savebackup.sh $BASEDIR/usr/local/sbin/savebackup
chmod 555 $BASEDIR/usr/local/sbin/savebackup

