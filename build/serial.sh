#!/bin/sh

# Copyright (c) 2014-2021 Franco Fichtner <franco@opnsense.org>
# Copyright (c) 2010-2011 Scott Ullrich <sullrich@gmail.com>
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

SELF=serial

. ./common.sh

check_image ${SELF} ${@}

SERIALIMG="${IMAGESDIR}/${PRODUCT_RELEASE}-serial-${PRODUCT_ARCH}.img"
SERIALLABEL="${PRODUCT_NAME}_Install"

sh ./clean.sh ${SELF}

setup_stage ${STAGEDIR} work
setup_base ${STAGEDIR}/work
setup_kernel ${STAGEDIR}/work
setup_packages ${STAGEDIR}/work
setup_extras ${STAGEDIR}/work ${SELF}
setup_mtree ${STAGEDIR}/work
setup_entropy ${STAGEDIR}/work

cat > ${STAGEDIR}/work/etc/fstab << EOF
# Device		Mountpoint	FStype	Options		Dump	Pass#
/dev/ufs/${SERIALLABEL}	/		ufs	ro,noatime	1	1
tmpfs			/tmp		tmpfs	rw,mode=01777	0	0
EOF

makefs -B little -o label=${SERIALLABEL} -o version=2 \
    ${STAGEDIR}/root.part ${STAGEDIR}/work

GPTDUMMY=
UEFIBOOT=

if [ -n "${PRODUCT_UEFI}" -a -z "${PRODUCT_UEFI%%*"${SELF}"*}" ]; then
	GPTDUMMY="-p freebsd-swap::512k"
	UEFIBOOT="-p efi:=efiboot.img"

	setup_efiboot ${STAGEDIR}/efiboot.img \
	    ${STAGEDIR}/work/boot/loader.efi
fi

echo -n ">>> Building serial image... "

(cd ${STAGEDIR}; mkimg -s gpt -o ${SERIALIMG} -b work/boot/pmbr ${UEFIBOOT} \
    -p freebsd-boot:=work/boot/gptboot ${GPTDUMMY} -p freebsd-ufs:=root.part)

echo "done"

sign_image ${SERIALIMG}
