#!/bin/sh

# Copyright (c) 2014-2016 Franco Fichtner <franco@opnsense.org>
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

SELF=vga

. ./common.sh && $(${SCRUB_ARGS})

check_images ${SELF} ${@}

VGAIMG="${IMAGESDIR}/${PRODUCT_RELEASE}-vga-${PRODUCT_ARCH}.img"

# rewrite the disk label, because we're install media
LABEL="${LABEL}_Install"

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
/dev/ufs/${LABEL}	/		ufs	ro,noatime	1	1
tmpfs			/tmp		tmpfs	rw,mode=01777	0	0
EOF

makefs -B little -o label=${LABEL} ${STAGEDIR}/root.part ${STAGEDIR}/work

UEFIBOOT=
if [ ${PRODUCT_ARCH} = "amd64" -a -n "${PRODUCT_UEFI}" ]; then
	UEFIBOOT="-p efi:=${STAGEDIR}/work/boot/boot1.efifat"
fi

mkimg -s gpt -o ${VGAIMG} -b ${STAGEDIR}/work/boot/pmbr ${UEFIBOOT} \
    -p freebsd-boot:=${STAGEDIR}/work/boot/gptboot \
    -p freebsd-ufs:=${STAGEDIR}/root.part
