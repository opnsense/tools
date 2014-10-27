#! /bin/sh
#
# Copyright (c) 2006 Matteo Riondato <rionda@FreeSBIE.org>
#
# See COPYING for licence terms
#
# $Id: savebackup.sh,v 1.1.1.1 2008/03/25 19:58:16 sullrich Exp $
#

TMPMNTDIR="/mnt"
ARCH_DIR="${TMPMNTDIR}/FreeSBIE/"
ARCH_NAME=`date "+freesbie_%Y%m%d_%H%M"`
ARCHIVE="${ARCH_DIR}${ARCH_NAME}.tar"
BKUP_LIST="/etc/backup.lst"

usage() {
	echo "usage: $0 backup_device"
}

_findfs() {
    local offset=${1}
    local value=${2}

    [ -z "${offset}" -o -z "${value}" ] && return 1

    local size=$((($(echo -n "${value}" | wc -c) + 1) / 2))

    [ "$(hexdump -v -e '1/1 "%X"' -s "${offset}" -n "${size}" "${harddisk}" 2>/dev/null)" = "${value}" ]

    return $?
}

findfs() {
  harddisk=${1}
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
EOF
    return 1
}


echo "FreeSBIE Backup Script"

if [ $# -ne 1 ]; then
	usage
	exit 1
elif [ ! -c /dev/$1 ]; then
	usage 
	exit 1
else
	FS=`findfs /dev/$1`
	case $FS in
	UFS2)
	      FSTYPE="ufs"
	      ;;
	FAT*)
	      FSTYPE="msdosfs"
	      ;;
	*)
	      echo "Slice /dev/$1 has a $FS filesystem. FreeBSD cannot write on $FS."
	      echo "Please choose another slice"
	      exit  
	      ;;
	esac
	mount -t $FSTYPE /dev/$1 ${TMPMNTDIR}
	if [ ! -e ${ARCH_DIR} ]; then
		mkdir ${ARCH_DIR}
	fi
fi

MARK=`cat ${BKUP_LIST} | grep -v "#" | grep -v "^-" | wc -l | awk '{print $1}'`
if [ ${MARK} -gt 10 ]; then
	MARK=10
fi
BKUPPED="0"
NEXT_MARK="1"

add_to_archive() {
	if [ -d $1 ]; then
		FILE_LIST=`find $1 -print0 | xargs -0`	
		NEW_FILE_LIST=""
		for i in `cat $BKUP_LIST | grep -v "#" | grep $1 \
				| grep "^-" | sed 's/^-//g'`; do
			for x in ${FILE_LIST}; do
				if [ ${x} != ${i} ]; then
					NEW_FILE_LIST=`echo $NEW_FILE_LIST $x`
				fi
			done
		done
		if [ "x$NEW_FILE_LIST" != "x" ]; then 
			FILE_LIST=$NEW_FILE_LIST
		fi
	else
		FILE_LIST=$1
	fi
	BKUPPING=`echo ${FILE_LIST} | wc -w | awk '{print $1}'`
	BKUPPED=$((${BKUPPED} + ${BKUPPING}))
	i=0
	while [ $i -lt $((${BKUPPING} / 5)) ]; do
		echo -n "."
		i=$(($i + 1))
	done 
	
	if [ ${BKUPPED} -ge ${NEXT_MARK} ]; then
		echo -n "."
		while [ ${NEXT_MARK} -lt ${BKUPPED} ]; do
			NEXT_MARK=$((${NEXT_MARK} + ${MARK}))
		done
	fi
	
	if [ ! -e $ARCHIVE ]; then
		tar ncpf $ARCHIVE $FILE_LIST 2> /dev/null
	else
		tar nrpf $ARCHIVE $FILE_LIST 2> /dev/null
	fi
}

echo -n "Adding files: "
for i in `cat ${BKUP_LIST} | grep -v "#" | grep -v "^-"`; do
	add_to_archive $i	
done
echo " Done"
echo -n "Compressing the archive:"
bzip2 ${ARCHIVE}
echo " Done"
sync
umount ${TMPMNTDIR}

