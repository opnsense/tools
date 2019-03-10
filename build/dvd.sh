#!/bin/sh

# Copyright (c) 2014-2019 Franco Fichtner <franco@opnsense.org>
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

SELF=dvd

. ./common.sh

check_image ${SELF} ${@}

DVDIMAGE="${IMAGESDIR}/${PRODUCT_RELEASE}-dvd-${PRODUCT_ARCH}.iso"
DVDLABEL=$(echo "${PRODUCT_NAME}_Install" | tr '[:lower:]' '[:upper:]')

sh ./clean.sh ${SELF}

setup_stage ${STAGEDIR} work mnt
setup_base ${STAGEDIR}/work
setup_kernel ${STAGEDIR}/work
setup_packages ${STAGEDIR}/work
setup_extras ${STAGEDIR}/work ${SELF}
setup_mtree ${STAGEDIR}/work
setup_entropy ${STAGEDIR}/work

UEFIBOOT=
if [ ${PRODUCT_ARCH} = "amd64" -a -n "${PRODUCT_UEFI}" ]; then
	dd if=/dev/zero of=${STAGEDIR}/efiboot.img bs=4k count=200
	DEV=$(mdconfig -a -t vnode -f ${STAGEDIR}/efiboot.img)
	newfs_msdos -F 12 -m 0xf8 /dev/${DEV}
	mount -t msdosfs /dev/${DEV} ${STAGEDIR}/mnt
	mkdir -p ${STAGEDIR}/mnt/efi/boot
	cp ${STAGEDIR}/work/boot/loader.efi \
	    ${STAGEDIR}/mnt/efi/boot/bootx64.efi
	umount ${STAGEDIR}/mnt
	mdconfig -d -u ${DEV}

	UEFIBOOT="-o bootimage=i386;${STAGEDIR}/efiboot.img"
	UEFIBOOT="${UEFIBOOT} -o no-emul-boot -o platformid=efi"
fi

echo -n ">>> Building dvd image... "

cat > ${STAGEDIR}/work/etc/fstab << EOF
# Device	Mountpoint	FStype	Options	Dump	Pass #
/dev/iso9660/${DVDLABEL}	/	cd9660	ro	0	0
tmpfs		/tmp		tmpfs	rw,mode=01777	0	0
EOF

makefs -t cd9660 \
    -o 'bootimage=i386;'"${STAGEDIR}"'/work/boot/cdboot' -o no-emul-boot \
    ${UEFIBOOT} -o label=${DVDLABEL} -o rockridge ${DVDIMAGE} ${STAGEDIR}/work

echo "done"
