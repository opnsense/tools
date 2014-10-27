#!/bin/sh
#
# Copyright (c) 2006 Matteo Riondato
#
# See COPYING for licence terms
#
# $Id: restorebackup.sh,v 1.1.1.1 2008/03/25 19:58:16 sullrich Exp $
#

#tmpmntdir=$(mktemp -d -t fsbiebk)
tmpmntdir="/mnt"

_findfs() {
    local offset=${1}
    local value=${2}

    [ -z "${offset}" -o -z "${value}" ] && return 1

    local size=$((($(echo -n "${value}" | wc -c) + 1) / 2))

    [ "$(hexdump -v -e '1/1 "%X"' -s "${offset}" -n "${size}" "${harddisk}" 2>/dev/null)" = "${value}" ]

    return $?
}

findfs() {
   harddisk=$1
   while read x; do
        local offset="$(echo "${x}" | cut -d : -f 2)"
        local value="$(echo "${x}" | cut -d : -f 3)"

        if _findfs "${offset}" "${value}"; then
            local fs="$(echo "${x}" | cut -d : -f 1)"
            echo "${fs}"
            return 0
        fi
    #description:offset:value
    done << EOF
        UFS2:0x1055C:1915419
        EXT:0x438:53EF
        FAT16:54:4641543136202020
        FAT32:82:4641543332202020
        FAT12:54:4641543132202020
        NTFS:3:4E54465320202020
        ISO9660:0x8001:4344303031
        XFS:0:42534658
        REISERFS:0x10034:5265497345724673
        REISERFS:0x10034:526549734572324673
        HFS+:0x400:2B48
        LINUXSWAP:0xFF6:53574150535041434532
EOF
    return 1
}


find_backup_dev() {
devlist=`/sbin/camcontrol devlist | cut -d\( -f 2 | cut -d\) -f 1 \
	| grep da | sed "s/.*da/da/" | sed "s/,.*//"`

if [ "x$devlist" != "x" ]; then
for i in ${devlist}; do
  FS=`findfs /dev/$i`
  case $FS in
  FAT*)
	mount_msdosfs /dev/$i ${tmpmntdir}	
	found=`ls ${tmpmntdir}/FreeSBIE/`
	if [ -n "${found}" ]; then
		backup_dev="/dev/$i"
		umount ${tmpmntdir}
		break
	fi
	;;
  *)
      ;;
  esac
done
fi
}

echo -n "Restoring backup: "

set +e
args=`getopt d:f:h`
if [ $? -ne 0 ]; then
	usage
	exit 2
fi
set -e

set -- $args
for i
do
	case "$i"
	in
	-d)
		backup_dev=$2
		shift;
		shift;
		;;
	-f)
		archive=$2
		shift;
		shift;
		;;
	-h)
		usage
		exit 0
		;;
	--)
		shift;
		break
	esac
done
if [ $# -gt 0 ] ; then
	echo "$0: Extraneous arguments supplied"
	usage
fi

if [ -z ${backup_dev} ]; then
	find_backup_dev
fi

if [ "x$backup_dev" != "x" ]; then
	FS=`findfs ${backup_dev}`
	case $FS in
	FAT*)
	    FSTYPE="msdosfs"
	    ;;
	UFS*)
	    FSTYPE="ufs"
	    ;;
	EXT)
	    FSTYPE="ext2fs"
	    ;;
	ISO*)
	    FSTYPE="cd9660"
	    ;;
	REISERFS*)
	    kldload reiserfs 2> /dev/null
	    FSTYPE="reiserfs"
	    ;;
	XFS)
	    kldload xfs 2> /dev/null
	    FSTYPE="xfs"
	    ;;
	NTFS)
	    FSTYPE="ntfs"
	    ;;
	*)
	  echo "Filesystem $FS not supported"
	  ;;
	esac

	mount -t $FSTYPE ${backup_dev} ${tmpmntdir}
	if [ -z ${archive} ]; then
		archive=`find ${tmpmntdir}/FreeSBIE/ -name "*freesbie_*" | tail -1`
	fi
	echo -n "Found backup on ${backup_dev}: `basename ${archive}`...Restoring..."
	tar -C / -xjPpf ${archive}
	umount ${tmpmntdir}
	echo "Done"
else
	echo "No backup found"
fi


