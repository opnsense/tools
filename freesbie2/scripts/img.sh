#!/bin/sh
#
# Copyright (c) 2005 Dario Freni
#
# See COPYING for licence terms.
#
# $FreeBSD$
# $Id: img.sh,v 1.1.1.1 2008/03/25 19:58:16 sullrich Exp $

set -e -u

if [ -z "${LOGFILE:-}" ]; then
    echo "This script can't run standalone."
    echo "Please use launch.sh to execute it."
    exit 1
fi

echo ">>> Building bootable UFS image for ${ARCH}..."

FREESBIE_LABEL=${FREESBIE_LABEL:-"FreeSBIE"} # UFS label

# Temp file and directory to be used later
TMPFILE=`mktemp -t freesbie`
TMPDIR=`mktemp -d -t freesbie`

# Size of cylinder in sectors
CYLSIZE=$((${SECTT} * ${HEADS}))

# Number of cylinders
CYLINDERS=$((${SECTS} / ${CYLSIZE}))

# Recalculate number of available sectors
SECTS=$((${CYLINDERS} * ${CYLSIZE}))

echo "Initializing image..."
rm -f ${IMGPATH}
dd if=/dev/zero of=${IMGPATH} count=1 seek=$((${SECTS} - 1)) >> ${LOGFILE} 2>&1

# Attach the md device
DEVICE=`mdconfig -a -t vnode -f ${IMGPATH} -x ${SECTT} -y ${HEADS}`

echo "g c${CYLINDERS} h${HEADS} s${SECTT}" > ${TMPFILE}
echo "p 1 165 ${SECTT} $((${SECTS} - ${SECTT}))" >> ${TMPFILE}
echo "a 1" >> ${TMPFILE}

fdisk -BI ${DEVICE} >> ${LOGFILE} 2>&1
fdisk -i -v -f ${TMPFILE} ${DEVICE} >> ${LOGFILE} 2>&1

bsdlabel -w -B ${DEVICE}s1 >> ${LOGFILE} 2>&1

newfs -b 4096 -f 512 -i 8192 -L ${FREESBIE_LABEL} -O1 -U ${DEVICE}s1a >> ${LOGFILE} 2>&1
mount /dev/${DEVICE}s1a ${TMPDIR}

echo "Done!"

echo -n ">>> Writing files..."

cd ${CLONEDIR}
find . -print -depth | cpio -dump -v ${TMPDIR} >> ${LOGFILE} 2>&1
echo "/dev/ufs/${FREESBIE_LABEL} / ufs ro 1 1" > ${TMPDIR}/etc/fstab
umount ${TMPDIR}
cd ${LOCALDIR}

mdconfig -d -u ${DEVICE}

rm -f ${TMPFILE}
rm -rf ${TMPDIR}

ls -lh ${IMGPATH}

echo "Done!"