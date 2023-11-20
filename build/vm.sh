#!/bin/sh

# Copyright (c) 2016-2022 Franco Fichtner <franco@opnsense.org>
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
VMEXTRAS=${SELF}

if [ -n "${1}" ]; then
	VMFORMAT=${1}
fi

if [ -n "${2}" ]; then
	VMSIZE=${2}
fi

if [ -n "${3}" ]; then
	if [ "${3}" != "off" -a "${3}" != "never" ]; then
		VMSWAP=${3}
	else
		VMSWAP=
	fi
fi

if [ -n "${4}" ]; then
	VMEXTRAS=${4}
fi

VMIMG="${IMAGESDIR}/${PRODUCT_RELEASE}-vm-${PRODUCT_ARCH}.${VMFORMAT}"
VMBASE="vmbase"

sh ./clean.sh ${SELF}

setup_stage ${STAGEDIR} mnt

truncate -s ${VMSIZE} ${STAGEDIR}/${VMBASE}
DEV=$(mdconfig -t vnode -f ${STAGEDIR}/${VMBASE})

if [ -n "${PRODUCT_ZFS}" ]; then
	ZPOOL=${PRODUCT_ZFS}

	# avoid clobbering existing pools
	for IMPORT in $(zpool import 2> /dev/null | awk '$1 == "pool:" { print $2}'); do
		if [ ${IMPORT} = ${ZPOOL} ]; then
			echo ">>> ZFS pool '${ZPOOL}' already exists"
			exit 1
		fi
	done

	# 4k sector alignment
	gnop create -S 4096 ${DEV}

	# create ZFS pool like installer would
	zpool create -R ${STAGEDIR}/mnt ${ZPOOL} ${DEV}.nop
	zfs create -o mountpoint=none ${ZPOOL}/ROOT
	zfs create -o mountpoint=/ ${ZPOOL}/ROOT/default
	zfs create -o mountpoint=/tmp -o exec=on -o setuid=off ${ZPOOL}/tmp
	zfs create -o mountpoint=/usr -o canmount=off ${ZPOOL}/usr
	zfs create ${ZPOOL}/usr/home
	zfs create -o setuid=off ${ZPOOL}/usr/ports
	zfs create ${ZPOOL}/usr/src
	zfs create -o mountpoint=/var -o canmount=off ${ZPOOL}/var
	zfs create -o exec=off -o setuid=off ${ZPOOL}/var/audit
	zfs create -o exec=off -o setuid=off ${ZPOOL}/var/crash
	zfs create -o exec=off -o setuid=off ${ZPOOL}/var/log
	zfs create -o atime=on ${ZPOOL}/var/mail
	zfs create -o setuid=off ${ZPOOL}/var/tmp
	zpool set bootfs=${ZPOOL}/ROOT/default ${ZPOOL}

	GPTNAME=gptzfsboot
	ROOTFS=zfs
else
	newfs /dev/${DEV}
	mount /dev/${DEV} ${STAGEDIR}/mnt

	GPTNAME=gptboot
	ROOTFS=ufs/rootfs
fi

setup_base ${STAGEDIR}/mnt

# need these again later
cp -R ${STAGEDIR}/mnt/boot ${STAGEDIR}

setup_kernel ${STAGEDIR}/mnt
setup_packages ${STAGEDIR}/mnt
setup_extras ${STAGEDIR}/mnt ${VMEXTRAS}
setup_entropy ${STAGEDIR}/mnt

cat > ${STAGEDIR}/mnt/etc/fstab << EOF
# Device	Mountpoint	FStype	Options	Dump	Pass#
EOF

if [ -z "${PRODUCT_ZFS}" ]; then
	cat >> ${STAGEDIR}/mnt/etc/fstab << EOF
/dev/gpt/rootfs	/		ufs	rw	1	1
EOF
	fi

GPTBOOT="-p freebsd-boot/bootfs:=boot/${GPTNAME}"
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

if [ -n "${PRODUCT_UEFI}" -a -z "${PRODUCT_UEFI%%*"${SELF}"*}" ]; then
	UEFIBOOT="-p efi/efifs:=efiboot.img"

	setup_efiboot ${STAGEDIR}/efiboot.img \
	    ${STAGEDIR}/boot/loader.efi $((260 * 1024))

	cat >> ${STAGEDIR}/mnt/etc/fstab << EOF
/dev/gpt/efifs	/boot/efi	msdosfs	rw	2	2
EOF
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

if [ "${3}" == "never" ]; then
	GPTDUMMY=
fi

if [ -n "${PRODUCT_ZFS}" ]; then
	zpool export ${ZPOOL}
else
	umount ${STAGEDIR}/mnt
fi
mdconfig -d -u ${DEV}

echo -n ">>> Building vm image... "

(cd ${STAGEDIR}; mkimg -s gpt -f ${VMFORMAT} -o ${VMIMG} \
    ${MBRBOOT} ${UEFIBOOT} ${GPTBOOT} ${GPTDUMMY} ${SWAPARGS} \
    -p freebsd-${ROOTFS}:=${VMBASE})

echo "done"

sign_image ${VMIMG}
