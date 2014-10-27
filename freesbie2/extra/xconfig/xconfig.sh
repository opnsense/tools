#!/bin/sh
#
# Copyright (c) 2002-2004 G.U.F.I.
# Copyright (c) 2005-2006 Matteo Riondato & Dario Freni
#
# See COPYING for licence terms.
#
# $Id: xconfig.sh,v 1.1.1.1 2008/03/25 19:58:16 sullrich Exp $
#
# Video Card Detection script
#
#
# PROVIDE: xconfig
# REQUIRE: etcmfs

. /etc/rc.subr

name="xconfig"
start_cmd="create_xorgconf"
stop_cmd=":"

create_xorgconf() {

if [ ! -f /usr/X11R6/bin/X ]; then
    exit
fi

echo -n "Creating xorg.conf..."

PATH_DEST=/etc/X11
X_CFG_ORIG=${PATH_DEST}/xorg.conf.orig
X_CFG=${PATH_DEST}/xorg.conf

if [ -f ${X_CFG} ]; then
    echo "xorg.conf found... skipping"
    exit
fi

pciconf="/usr/sbin/pciconf -lv"

pciline=$(${pciconf} | grep -B 4 VGA | head -n 1)

vendor_id=$(echo ${pciline} | awk '{print "0x" substr($4,12)}')
device_id=$(echo ${pciline} | awk '{print substr($4,6,6)}')
revision=$(echo ${pciline} | awk '{print substr($5,5)}')
subsysvendor_id=$(echo ${pciline} | awk '{print "0x" substr($3,12)}')
subsys_id=$(echo ${pciline} | awk '{print substr($3,6,6)}')
class=$(echo ${pciline} | awk '{print substr($2,7,6)}')

DRIVER_STR=$(/usr/X11R6/bin/getconfig -X 60900000 -I /etc/X11,/usr/X11R6/etc/X11,/usr/X11R6/lib/modules,/usr/X11R6/lib/X11/getconfig -v ${vendor_id} -d ${device_id} -r ${revision} -s ${subsysvendor_id} -b ${subsys_id} -c ${class} 2> /dev/null)

echo -n " using \"${DRIVER_STR}\" driver..."

case "${DRIVER_STR:-NULL}" in
NULL)
	echo "no drivers found... using vesa"
	cp ${X_CFG_ORIG} ${X_CFG}
	;;
vesa)
	cp ${X_CFG_ORIG} ${X_CFG}
	;;
*)
	sed "s/vesa/${DRIVER_STR}/" < ${X_CFG_ORIG} > ${X_CFG}
	;;
esac

echo " done."

}

load_rc_config $name
run_rc_command "$1"

