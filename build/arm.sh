#!/bin/sh

# Copyright (c) 2017-2025 Franco Fichtner <franco@opnsense.org>
# Copyright (c) 2015-2017 The FreeBSD Foundation
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

SELF=arm

. ./common.sh

if [ ${PRODUCT_ARCH} != armv6 \
    -a ${PRODUCT_ARCH} != armv7 \
    -a ${PRODUCT_ARCH} != aarch64 ]; then
	echo ">>> Cannot build arm image with arch ${PRODUCT_ARCH}"
	exit 1
fi

check_image ${SELF} ${@}

ARMSIZE="3G"

if [ -n "${1}" ]; then
	ARMSIZE=${1}
fi

ARMIMG="${IMAGESDIR}/${PRODUCT_RELEASE}-arm-${PRODUCT_ARCH}${PRODUCT_DEVICE+"-${PRODUCT_DEVICE}"}.img"
ARMLABEL="${PRODUCT_NAME}"

sh ./clean.sh ${SELF}

setup_stage ${STAGEDIR}

truncate -s ${ARMSIZE} ${ARMIMG}

DEV=$(mdconfig -a -t vnode -f ${ARMIMG} -x 63 -y 255)

ARM_FAT_SIZE=${ARM_FAT_SIZE:-"50m -b 1m"}

gpart create -s MBR ${DEV}
gpart add -t '!12' -a 512k -s ${ARM_FAT_SIZE} ${DEV}
gpart set -a active -i 1 ${DEV}
newfs_msdos -L msdosboot -F 16 /dev/${DEV}s1
gpart add -t freebsd ${DEV}
gpart create -s bsd ${DEV}s2
gpart add -t freebsd-ufs -a 64k /dev/${DEV}s2
newfs -U -L ${ARMLABEL} /dev/${DEV}s2a
mount /dev/${DEV}s2a ${STAGEDIR}

setup_base ${STAGEDIR}
setup_kernel ${STAGEDIR}
setup_xtools ${STAGEDIR}
setup_packages ${STAGEDIR}
setup_extras ${STAGEDIR} ${SELF}
setup_entropy ${STAGEDIR}
setup_xbase ${STAGEDIR}

cat > ${STAGEDIR}/etc/fstab << EOF
# Device		Mountpoint	FStype	Options		Dump	Pass#
/dev/ufs/${ARMLABEL}	/		ufs	rw		1	1
/dev/msdosfs/MSDOSBOOT	/boot/msdos	msdosfs	rw,noatime	0	0
EOF

mkdir -p ${STAGEDIR}/boot/msdos
mount_msdosfs /dev/${DEV}s1 ${STAGEDIR}/boot/msdos

arm_mount()
{
	mount /dev/${DEV}s2a ${STAGEDIR}
	mount_msdosfs /dev/${DEV}s1 ${STAGEDIR}/boot/msdos
}

arm_unmount()
{
	sync
	umount ${STAGEDIR}/boot/msdos
	umount ${STAGEDIR}
}

arm_install_uboot

if [ -n "${PRODUCT_UEFI}" -a -z "${PRODUCT_UEFI%%*"${SELF}"*}" ]; then
	setup_efiboot ${STAGEDIR}/efiboot.img ${STAGEDIR}/boot/loader.efi
	cp -r ${STAGEDIR}/efiboot.img.d/efi ${STAGEDIR}/boot/msdos/efi
fi

echo -n ">>> Building arm image... "

arm_unmount
mdconfig -d -u ${DEV}

echo "done"

sign_image ${ARMIMG}
