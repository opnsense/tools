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
VMBASE="${STAGEDIR}/vmbase"

sh ./clean.sh ${SELF}

setup_stage ${STAGEDIR} mnt

truncate -s ${VMSIZE} ${VMBASE}
DEV=$(mdconfig -t vnode -f ${VMBASE})
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

GPTDUMMY="-p freebsd-swap::512k"
SWAPARGS=
UEFIBOOT=

if [ ${PRODUCT_ARCH} = "amd64" -o ${PRODUCT_ARCH} = "aarch64" -a -n "${PRODUCT_UEFI}" -a \
    -z "${PRODUCT_UEFI%%*"${SELF}"*}" ]; then
	UEFIBOOT="-p efi:=${STAGEDIR}/boot/boot1.efifat"
fi

if [ -n "${VMSWAP}" ]; then
	SWAPARGS="-p freebsd-swap/swapfs::${VMSWAP}"
	cat >> ${STAGEDIR}/mnt/etc/fstab << EOF
/dev/gpt/swapfs	none		swap	sw	0	0
EOF
fi

if [ -z "${VMSWAP}" -a -z "${UEFIBOOT}" ]; then
	GPTDUMMY=
elif [ -n "${VMSWAP}" -a -n "${UEFIBOOT}" ]; then
	GPTDUMMY=
fi

umount ${STAGEDIR}/mnt
mdconfig -d -u ${DEV}

echo -n ">>> Building vm image... "

if [ ${PRODUCT_ARCH} = "aarch64" ]; then
	mkimg -s gpt -f ${VMFORMAT} -o ${VMIMG} \
		${UEFIBOOT} \
		-p freebsd-ufs/rootfs:=${VMBASE} ${SWAPARGS}
else
	mkimg -s gpt -f ${VMFORMAT} -o ${VMIMG} -b ${STAGEDIR}/boot/pmbr \
		${UEFIBOOT} -p freebsd-boot/bootfs:=${STAGEDIR}/boot/gptboot \
		${GPTDUMMY} -p freebsd-ufs/rootfs:=${VMBASE} ${SWAPARGS}
fi

echo "done"
