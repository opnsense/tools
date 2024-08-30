#!/bin/sh

# Copyright (c) 2014-2021 Franco Fichtner <franco@opnsense.org>
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

if [ -z "${PRODUCT_UEFI}" -o -n "${PRODUCT_UEFI%%*"${SELF}"*}" ]; then
	echo ">>> BIOS-only DVD images are no longer supported" >&2
	exit 1
fi

check_image ${SELF} ${@}

DVDIMG="${IMAGESDIR}/${PRODUCT_RELEASE}-dvd-${PRODUCT_ARCH}.iso"
DVDLABEL=$(echo "${PRODUCT_NAME}_Install" | tr '[:lower:]' '[:upper:]')

sh ./clean.sh ${SELF}

setup_stage ${STAGEDIR} work mnt
setup_base ${STAGEDIR}/work
setup_kernel ${STAGEDIR}/work
setup_packages ${STAGEDIR}/work
setup_extras ${STAGEDIR}/work ${SELF}
setup_mtree ${STAGEDIR}/work
setup_entropy ${STAGEDIR}/work

BOOTIMAGE=i386

if [ ${PRODUCT_ARCH} != "amd64" ]; then
	BOOTIMAGE=efi
fi

UEFIBOOT="-o bootimage=${BOOTIMAGE};${STAGEDIR}/efiboot.img"
LEGACYBOOT="-o bootimage=${BOOTIMAGE};${STAGEDIR}/work/boot/cdboot -o no-emul-boot"

# keep legacy boot compatibility on amd64 only
if [ ${PRODUCT_ARCH} != "amd64" ]; then
	UEFIBOOT="${UEFIBOOT} -o platformid=efi"
	LEGACYBOOT=
fi

setup_efiboot ${STAGEDIR}/efiboot.img ${STAGEDIR}/work/boot/loader.efi 2048 12

cat > ${STAGEDIR}/work/etc/fstab << EOF
# Device	Mountpoint	FStype	Options	Dump	Pass #
/dev/iso9660/${DVDLABEL}	/	cd9660	ro	0	0
tmpfs		/tmp		tmpfs	rw,mode=01777	0	0
EOF

echo -n ">>> Building dvd image... "

makefs -t cd9660 ${LEGACYBOOT} ${UEFIBOOT} -o label=${DVDLABEL} \
    -o rockridge ${DVDIMG} ${STAGEDIR}/work

echo "done"

sign_image ${DVDIMG}
