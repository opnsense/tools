#!/bin/sh
#
# Copyright (c) 2006 Matteo Riondato
#
# See COPYING for licence details
#
# $Id: mountdisksrc.sh,v 1.1.1.1 2008/03/25 19:58:16 sullrich Exp $
#
# PROVIDE mountdisks
# REQUIRE mountcriticlocal dmesg

. /etc/rc.subr

name="mountdisks"
start_cmd="do_mountdisks"
stop_cmd=":"

do_mountdisks()
{
	do_mount=`kenv -q freesbie.mountdisks`
	if [ "${do_mount}" = "yes" -o "${do_mount}" = "YES" ]; then
		sh /usr/local/sbin/mountdisks rw
	fi
}

load_rc_config $name
run_rc_command "$1"
