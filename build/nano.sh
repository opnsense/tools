#!/bin/sh

# Copyright (c) 2015-2016 Franco Fichtner <franco@opnsense.org>
# Copyright (c) 2004-2009 Scott Ullrich <sullrich@gmail.com>
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

NANOSIZE="3800M"

if [ -n "${1}" ]; then
	NANOSIZE=${1}
fi

NANOIMG="${IMAGESDIR}/${PRODUCT_RELEASE}-nano-${PRODUCT_ARCH}.img"
NANOBASE="${STAGEDIR}/nanobase"

sh ./clean.sh ${SELF}

setup_stage ${STAGEDIR} mnt

truncate -s ${NANOSIZE} ${NANOBASE}
MD=$(mdconfig -f ${NANOBASE})
newfs /dev/${MD}
mount /dev/${MD} ${STAGEDIR}/mnt

setup_base ${STAGEDIR}/mnt

# need these again later
cp -r ${STAGEDIR}/mnt/boot ${STAGEDIR}

setup_kernel ${STAGEDIR}/mnt
setup_packages ${STAGEDIR}/mnt
setup_extras ${STAGEDIR}/mnt ${SELF}
setup_entropy ${STAGEDIR}/mnt

echo "/dev/ufs/${LABEL} / ufs rw,async,noatime 1 1" > ${STAGEDIR}/mnt/etc/fstab

umount ${STAGEDIR}/mnt
mdconfig -d -u ${MD}

echo -n ">>> Building nano image... "

mkimg -s bsd -f raw -o ${NANOIMG} \
    -b ${STAGEDIR}/boot/boot \
    -p freebsd-ufs:=${NANOBASE}

# mkimg does not support BSD label yet
MD=$(mdconfig -f ${NANOIMG})
tunefs -L ${LABEL} /dev/${MD}a
mdconfig -d -u ${MD}

echo "done"
