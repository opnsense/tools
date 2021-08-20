#!/bin/sh

# Copyright (c) 2016-2021 Franco Fichtner <franco@opnsense.org>
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

SELF=vm

. ./common.sh

check_image ${SELF} ${@}

VMFORMAT="vmdk"
VMSIZE="20G"
VMSWAP="1G"

if [ -n "${1}" ]; then
	VMFORMAT=${1}
fi

if [ -n "${2}" ]; then
	VMSIZE=${2}
fi

if [ -n "${3}" ]; then
	if [ "${3}" != "off" ]; then
		VMSWAP=${3}
	else
		VMSWAP=
	fi
fi

VMIMG="${IMAGESDIR}/${PRODUCT_RELEASE}-vm-${PRODUCT_ARCH}.${VMFORMAT}"
VMBASE="vmbase"

sh ./clean.sh ${SELF}

setup_stage ${STAGEDIR} mnt

truncate -s ${VMSIZE} ${STAGEDIR}/${VMBASE}
DEV=$(mdconfig -t vnode -f ${STAGEDIR}/${VMBASE})
newfs /dev/${DEV}
mount /dev/${DEV} ${STAGEDIR}/mnt

setup_base ${STAGEDIR}/mnt

# need these again later
cp -R ${STAGEDIR}/mnt/boot ${STAGEDIR}

setup_kernel ${STAGEDIR}/mnt
setup_packages ${STAGEDIR}/mnt
setup_extras ${STAGEDIR}/mnt ${SELF}
setup_entropy ${STAGEDIR}/mnt

cat > ${STAGEDIR}/mnt/etc/fstab << EOF
# Device	Mountpoint	FStype	Options	Dump	Pass#
/dev/gpt/rootfs	/		ufs	rw	1	1
EOF

GPTBOOT="-p freebsd-boot/bootfs:=boot/gptboot"
GPTDUMMY="-p freebsd-swap::512k"
MBRBOOT="-b boot/pmbr"
SWAPARGS=
UEFIBOOT=

if [ -n "${VMSWAP}" ]; then
	SWAPARGS="-p freebsd-swap/swapfs::${VMSWAP}"
	cat >> ${STAGEDIR}/mnt/etc/fstab << EOF
/dev/gpt/swapfs	none		swap	sw	0	0
EOF
fi

umount ${STAGEDIR}/mnt
mdconfig -d -u ${DEV}

if [ -n "${PRODUCT_UEFI}" -a -z "${PRODUCT_UEFI%%*"${SELF}"*}" ]; then
	UEFIBOOT="-p efi:=efiboot.img"

	setup_efiboot ${STAGEDIR}/efiboot.img \
	    ${STAGEDIR}/boot/loader.efi
fi

if [ ${PRODUCT_ARCH} = "aarch64" ]; then
	GPTBOOT=
	MBRBOOT=

	# produce even number of partitions
	if [ -n "${VMSWAP}" -a -z "${UEFIBOOT}" ]; then
		GPTDUMMY=
	elif [ -z "${VMSWAP}" -a -n "${UEFIBOOT}" ]; then
		GPTDUMMY=
	fi
else
	# produce even number of partitions
	if [ -z "${VMSWAP}" -a -z "${UEFIBOOT}" ]; then
		GPTDUMMY=
	elif [ -n "${VMSWAP}" -a -n "${UEFIBOOT}" ]; then
		GPTDUMMY=
	fi
fi

echo -n ">>> Building vm image... "

(cd ${STAGEDIR}; mkimg -s gpt -f ${VMFORMAT} -o ${VMIMG} \
    ${MBRBOOT} ${UEFIBOOT} ${GPTBOOT} ${GPTDUMMY} \
    -p freebsd-ufs/rootfs:=${VMBASE} ${SWAPARGS})

echo "done"
