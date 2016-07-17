#!/bin/sh

# Copyright (c) 2015-2016 Franco Fichtner <franco@opnsense.org>
# Copyright (c) 2004-2009 Scott Ullrich <sullrich@gmail.com>
# Copyright (c) 2005 Poul-Henning Kamp <phk@FreeBSD.org>
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

set -e

SELF=nano

. ./common.sh && $(${SCRUB_ARGS})

check_images ${SELF} ${@}

NANOIMG="${IMAGESDIR}/${PRODUCT_RELEASE}-nano-${PRODUCT_ARCH}.img"

sh ./clean.sh ${SELF}

. ${SRCDIR}/tools/tools/nanobsd/FlashDevice.sub
sub_FlashDevice generic 4g

# chop off excess bytes that do not align to 8 byte boundary
NANO_MEDIASIZE=$(expr ${NANO_MEDIASIZE} - \( ${NANO_MEDIASIZE} % 8 \))

setup_stage ${STAGEDIR} mnt work
setup_base ${STAGEDIR}/work
setup_kernel ${STAGEDIR}/work
setup_packages ${STAGEDIR}/work
setup_serial ${STAGEDIR}/work
setup_extras ${STAGEDIR}/work ${SELF}

MD=$(mdconfig -a -t swap -s ${NANO_MEDIASIZE} -x ${NANO_SECTS} -y ${NANO_HEADS})

# NanoBSD knobs; do not change lightly
NANO_IMAGES=2
NANO_CODESIZE=0
NANO_DATASIZE=0
NANO_CONFSIZE=102400

echo $NANO_MEDIASIZE $NANO_IMAGES \
	$NANO_SECTS $NANO_HEADS \
	$NANO_CODESIZE $NANO_CONFSIZE $NANO_DATASIZE |
awk '
{
	printf "# %s\n", $0

	# size of cylinder in sectors
	cs = $3 * $4

	# number of full cylinders on media
	cyl = int ($1 / cs)

	# output fdisk geometry spec, truncate cyls to 1023
	if (cyl <= 1023)
		print "g c" cyl " h" $4 " s" $3
	else
		print "g c" 1023 " h" $4 " s" $3

	if ($7 > 0) {
		# size of data partition in full cylinders
		dsl = int (($7 + cs - 1) / cs)
	} else {
		dsl = 0;
	}

	# size of config partition in full cylinders
	csl = int (($6 + cs - 1) / cs)

	if ($5 == 0) {
		# size of image partition(s) in full cylinders
		isl = int ((cyl - dsl - csl) / $2)
	} else {
		isl = int (($5 + cs - 1) / cs)
	}

	# First image partition start at second track
	print "p 1 165 " $3, isl * cs - $3
	c = isl * cs;

	# Second image partition (if any) also starts offset one
	# track to keep them identical.
	if ($2 > 1) {
		print "p 2 165 " $3 + c, isl * cs - $3
		c += isl * cs;
	}

	# Config partition starts at cylinder boundary.
	print "p 3 165 " c, csl * cs
	c += csl * cs

	# Data partition (if any) starts at cylinder boundary.
	if ($7 > 0) {
		print "p 4 165 " c, dsl * cs
	} else if ($7 < 0 && $1 > c) {
		print "p 4 165 " c, $1 - c
	} else if ($1 < c) {
		print "Disk space overcommitted by", \
		    c - $1, "sectors" > "/dev/stderr"
		exit 2
	}

	# Force slice 1 to be marked active. This is necessary
	# for booting the image from a USB device to work.
	print "a 1"
}
' | fdisk -i -f - ${MD}

boot0cfg -B -b ${STAGEDIR}/work/boot/boot0sio -o packet -s 1 -m 3 ${MD}

setup_partition()
{
	# args 1:slice 2:label 3:mount 4:root

	echo "/dev/ufs/${2} / ufs rw,async,noatime 1 1" > ${4}/etc/fstab

	bsdlabel -w -B -b ${4}/boot/boot ${1}
	newfs -b 4096 -f 512 -i 8192 -U ${1}a
	tunefs -L ${2} ${1}a
	mount -o async ${1}a ${3}
	df -i ${3}
	(cd ${4}; find . -print | cpio -dump ${3})
	df -i ${3}
	umount ${3}
}

setup_entropy ${STAGEDIR}/work
setup_partition /dev/${MD}s1 ${LABEL}0 ${STAGEDIR}/mnt ${STAGEDIR}/work

if [ ${NANO_IMAGES} -gt 1 ]; then
	setup_entropy ${STAGEDIR}/work
	setup_partition /dev/${MD}s2 ${LABEL}1 ${STAGEDIR}/mnt ${STAGEDIR}/work
fi

# move image from RAM to output file
dd if=/dev/${MD} of=${NANOIMG} bs=64k
mdconfig -d -u ${MD}
