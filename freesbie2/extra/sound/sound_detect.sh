#!/bin/sh
#
# Copyright 2002-2005 G.U.F.I. All rights reserved.
# Copyright 2006 Timothy Redaelli
#
# See COPYING for licence terms
#
# $Id: sound_detect.sh,v 1.1.1.1 2008/03/25 19:58:16 sullrich Exp $
#
# Detect the audio card and load the appropriate driver
#
# PROVIDE: sound_detect

. /etc/rc.subr

name="sound_detect"
start_cmd="do_sound_detect"
stop_cmd=":"

do_sound_detect() 
{
	
CARD_FILE=/usr/local/share/sound/snd_card_ids.txt
pciconf -lv | awk -F '[ =]' '/^none/{print $6}' | while read i
do
	SND_DRIVER=`fgrep $i $CARD_FILE | cut -d: -f 1`
	if [ "$SND_DRIVER" ]; then
		echo -n "Loading $SND_DRIVER.ko... "
		/sbin/kldload /boot/kernel/$SND_DRIVER.ko
		echo "[OK]";
	fi
done
}

load_rc_config $name
run_rc_command "$1"

