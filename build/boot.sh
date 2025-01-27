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

MEM=3092
SELF=boot

. ./common.sh

if [ -z "${1}" ]; then
	echo ">>> No image given."
	exit 1
fi

IMAGE=$(find_image "${1}")

if [ ! -f "${IMAGE}" ]; then
	echo ">>> No image found."
	exit 1
fi

AHCI=ahci-hd; if [ "${1}" = "dvd" ]; then AHCI=ahci-cd;fi

setup_stage ${STAGEDIR}

TARGET=${STAGEDIR}/image.img
SPARE=${STAGEDIR}/disk.img

if [ -z "${IMAGE%%*.bz2}" ]; then
	echo -n ">>> Uncompressing image ${IMAGE}... "
	bunzip2 -c ${IMAGE} > ${TARGET}
	echo "done"
else
	cp ${IMAGE} ${TARGET}
fi

truncate -s +5G ${TARGET}
truncate -s 10G ${SPARE}

echo ">>> Booting image ${IMAGE}:"

BRGDEV=bridge0
TAPLAN=tap0
TAPWAN=tap1
PHYDEV=em0

if ! ifconfig ${BRGDEV}; then BRGDEV=$(ifconfig bridge create); fi
if ! ifconfig ${TAPLAN}; then TAPLAN=$(ifconfig tap create); fi
if ! ifconfig ${TAPWAN}; then TAPWAN=$(ifconfig tap create); fi

ifconfig ${BRGDEV} addm ${TAPWAN} addm ${PHYDEV} up || true
ifconfig ${TAPWAN} up

kldstat -qm vmm || kldload vmm
bhyveload -m ${MEM} -d ${TARGET} vm0
while bhyve -c 1 -m ${MEM} -AHP \
    -s 0,hostbridge \
    -s 1:0,virtio-net,${TAPLAN} \
    -s 1:1,virtio-net,${TAPWAN} \
    -s 2:0,${AHCI},${TARGET} \
    -s 3:0,ahci-hd,${SPARE} \
    -s 31,lpc -l com1,stdio \
    vm0; do
	bhyvectl --destroy --vm=vm0
	bhyveload -m ${MEM} -d ${TARGET} vm0
done
bhyvectl --destroy --vm=vm0
