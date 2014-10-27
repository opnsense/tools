#!/bin/sh
#
# Copyright (c) Edson Branti
# Copyright (c) 2006 Timothy Redaelli - Matteo Riondato
#
#$Id: mountdisks.sh,v 1.1.1.1 2008/03/25 19:58:16 sullrich Exp $

###############################################
# We will try to detect a set of disks and
# existing slices and try to mount every
# FAT16/32, NTFS, UFS, EXT2, ReiserFS partition we find.
###############################################

set -e -u

MOUNT_OPTION=

UFS_PART=1
MSDOS_PART=1
NTFS_PART=1
EXT2FS_PART=1
REISERFS_PART=1

UFS_TOO_MANY=0
MSDOS_TOO_MANY=0
NTFS_TOO_MANY=0
EXT2FS_TOO_MANY=0
REISERFS_TOO_MANY=0

#_swap() {
#    data=${1}

#    until [ -z "${data}" ]; do
#        tmp="$(echo ${data} | cut -b -2)"
#        data="$(echo ${data} | cut -b 3-)"
#        buf="${tmp}${buf}"
#    done

#    echo ${buf}
#}

OPTION=`echo $@`
if [ "${OPTION}" != "rw" -a "${OPTION}" != "ro" ]; then
	echo "Program: mountdisks.sh"
	echo "Parameters:" 
	echo "   - ro mounts partitions in READ ONLY mode;"
	echo "   - rw mounts partitions in READ/WRITE mode."
	exit 1
fi
if [ "${OPTION}" = "ro" ]; then
	MOUNT_OPTION="-r"
fi


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

for i in `egrep "^(aacd|ad|ar|amrd|da|fla|idad|ips|mlxd|mlyd|pst|twed|wd)[0-9]:" /var/run/dmesg.boot | cut -d':' -f1 | sort -u`; do
    find "/dev" -name "${i}s?" | while read a; do
        case `findfs ${a}` in
        UFS*)
            if [ ${UFS_PART} -le 8 ]; then
                echo "UFS slice found at ${a}, detecting partitions..."
                disklabel -r "${a}" 2>/dev/null | awk -F'[: ]' '/BSD/{print $3}' | while read j; do
                    if [ ${UFS_PART} -le 8 ]; then
                        echo "UFS partition found at ${a}${j}, mounting it under /mnt/ufs.${UFS_PART}"
                        mount ${MOUNT_OPTION} ${a}${j} /mnt/ufs.${UFS_PART} >/dev/null 2>&1
                        UFS_PART=$((${UFS_PART} + 1))
                    else
                        echo "Too many partitions found, only 8 can be mounted simultaneously."
                    fi
                done
            else
                echo "Too many partitions found, only 8 can be mounted simultaneously."
            fi
        ;;
        EXT)
            if [ ${EXT2FS_PART} -le 8 ]; then
                echo "EXT2FS slice found at ${a}, mounting it under /mnt/ext2fs.${EXT2FS_PART} ..."
                mount -t ext2fs ${MOUNT_OPTION} ${a} /mnt/ext2fs.${EXT2FS_PART} >/dev/null 2>&1
                EXT2FS_PART=$(({EXT2FS_PART} + 1))
            else
                echo "Too many slices found, only 8 can be mounted simultaneously."
            fi
        ;;
        FAT*)
            if [ ${MSDOS_PART} -le 8 ]; then
                echo "FAT16/32 slice found at ${a}, mounting it under /mnt/dos.${MSDOS_PART} ..."
                mount -t msdos ${MOUNT_OPTION} ${a} /mnt/dos.${MSDOS_PART} >/dev/null 2>&1
                MSDOS_PART=$((${MSDOS_PART} + 1))
            else
                echo "Too many slices found, only 8 can be mounted simultaneously."
            fi
        ;;
        NTFS)
            if [ ${NTFS_PART} -le 8 ]; then
                echo "NTFS slice found at ${a}, mounting it under /mnt/ntfs.${NTFS_PART} ..."
                mount -t ntfs ${a} /mnt/ntfs.${NTFS_PART} >/dev/null 2>&1
                NTFS_PART=$((${NTFS_PART} + 1))
            else
                echo "Too many slices found, only 8 can be mounted simultaneously."
            fi
        ;;
        REISERFS)
	    if ! kldstat -q -m reiserfs ; then
		kldload reiserfs
	    fi

            if [ ${REISERFS_PART} -le 8 ]; then
                echo "ReiserFS slice found at ${a}, mounting it under /mnt/reiser.${REISERFS_PART} ..."
                mount -t reiserfs ${a} /mnt/reiser.${REISERFS_PART} >/dev/null 2>&1
                REISERFS_PART=$((${REISERFS_PART} + 1))
            else
                echo "Too many slices found, only 8 can be mounted simultaneously."
            fi
        ;;
        *)
        ;;
        esac
    done
done
