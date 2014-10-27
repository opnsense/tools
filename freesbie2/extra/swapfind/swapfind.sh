#!/bin/sh
#
# Copyright (c) 2005 Matteo Riondato
# Copyright (c) 2006 Timothy Redaelli
#
# See COPYING for licence terms.
#
#
# $Id: swapfind.sh,v 1.1.1.1 2008/03/25 19:58:16 sullrich Exp $
#
# PROVIDE: swapfind
# REQUIRE: mountcritlocal dmesg

. /etc/rc.subr

name="swapfind"
start_cmd="swapfind_start"
stop_cmd=":"


swapfind_start() {

awk -F: '/^(ad|ar|da)[0-9]:/ {print $1}' /var/run/dmesg.boot | sort -u | while read disk
do
	slice=1

	fdisk $disk | awk /sysid/'{print $2}' | while read sltype
	do
		if [ "$sltype" = "165" ]; then
			bsdlabel -r /dev/${disk}s${slice} 2>/dev/null | awk -F '[ :]+' '/swap/{print $2}' | while read part
			do
				/sbin/swapon /dev/${disk}s${slice}${part}
			done
		fi

		slice=$(($slice + 1))
	done
done

}

load_rc_config $name
run_rc_command "$1"

