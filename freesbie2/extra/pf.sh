#!/bin/sh
#
# Copyright (c) 2006 Dominique Goncalves
#
# See COPYING for licence terms.
#
#
# $Id: pf.sh,v 1.1.1.1 2008/03/25 19:58:15 sullrich Exp $

set -e -u

if [ -z "${LOGFILE:-}" ]; then
	echo "This script can't run standalone."
	echo "Please use launch.sh to execute it."
	exit 1
fi

echo "pf_rules_enable=\"YES\"" >> $BASEDIR/etc/rc.conf
echo "pf_enable=\"YES\"" >> $BASEDIR/etc/rc.conf

cp extra/pf/pf_rules.sh $BASEDIR/etc/rc.d/pf_rules
chmod 555 $BASEDIR/etc/rc.d/pf_rules
