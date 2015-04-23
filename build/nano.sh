#!/bin/sh

# Copyright (c) 2015 Franco Fichtner <franco@opnsense.org>
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

. ./common.sh

. ${SRCDIR}/tools/tools/nanobsd/FlashDevice.sub
sub_FlashDevice sandisk 1g

mkdir -p ${IMAGESDIR}

setup_stage ${STAGEDIR}
setup_base ${STAGEDIR}
setup_kernel ${STAGEDIR}
setup_packages ${STAGEDIR} opnsense

echo "/dev/ufs/OPNsense0 / ufs rw,async,noatime 1 1" > ${STAGEDIR}/etc/fstab

# Activate serial console boot
echo "-S115200 -D" > ${STAGEDIR}/boot.config

# Activate serial console in config.xml
DEFAULTCONF=${STAGEDIR}/usr/local/etc/config.xml
# If it wasn't there before, enable serial in the config:
if ! grep -q -F "<enableserial/>" ${DEFAULTCONF}; then
	sed -i "" -e "s:</system>:<enableserial/></system>:" ${DEFAULTCONF}
fi

# Activate serial console+video console
cat > ${STAGEDIR}/boot/loader.conf <<EOF
boot_multicons="YES"
boot_serial="YES"
console="comconsole,vidconsole"
comconsole_speed="115200"
EOF

# Activate serial console TTY
sed -i "" -Ee 's:^ttyu0:ttyu0	"/usr/libexec/getty std.9600"	cons25	on  secure:' ${STAGEDIR}/etc/ttys

MD=`mdconfig -a -t swap -s ${NANO_MEDIASIZE} -x ${NANO_SECTS} -y ${NANO_HEADS}`

# NanoBSD knobs; do not change lightly
NANO_IMAGES=1
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

# Bootstrap the boot loader and boot0 for convenience
boot0cfg -B -b ${STAGEDIR}/boot/boot0sio -o packet -s 1 -m 3 ${MD}
bsdlabel -w -B -b ${STAGEDIR}/boot/boot ${MD}s1

MNT=/tmp/nanobsd.${$}
mkdir -p ${MNT}

# We only ever set up one slice and ignore everything else
newfs -b 4096 -f 512 -i 8192 -O1 -U /dev/${MD}s1a
tunefs -L OPNsense0 /dev/${MD}s1a
mount -o async /dev/${MD}s1a ${MNT}
df -i ${MNT}
cd ${STAGEDIR} && find . -print | cpio -dump ${MNT}
df -i ${MNT}
umount ${MNT}

rm -rf /tmp/nanobsd.*

dd if=/dev/${MD} of=${NANOIMG} bs=64k
mdconfig -d -u ${MD}

echo "done:"

ls -lah ${IMAGESDIR}/*
