#!/bin/sh
#
# Copyright (c) 2005 Matteo Riondato & Dario Freni
#
# See COPYING for licence terms.
#
#
# $Id: xconfig.sh,v 1.1.1.1 2008/03/25 19:58:15 sullrich Exp $

set -e -u

if [ -z "${LOGFILE:-}" ]; then
	echo "This script can't run standalone."
	echo "Please use launch.sh to execute it."
	exit 1
fi

mkdir -p $BASEDIR/etc/X11/ $BASEDIR/etc/rc.d/ $BASEDIR/usr/local/sbin/

cp extra/xconfig/xorg.conf.orig $BASEDIR/etc/X11/

cp extra/xconfig/xconfig.sh $BASEDIR/etc/rc.d/xconfig
chmod 555 $BASEDIR/etc/rc.d/xconfig

# XXX Remember to trigger it on your login scripts or in rc.local
cp extra/xconfig/xkbdlayout.sh $BASEDIR/usr/local/sbin/
