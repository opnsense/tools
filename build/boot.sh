#!/bin/sh

# Copyright (c) 2016-2020 Franco Fichtner <franco@opnsense.org>
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

SELF=boot

. ./common.sh

if [ -z "${1}" ]; then
	echo ">> No image given."
	exit 1
fi

IMAGE=$(find ${IMAGESDIR} -name "*-${1}-${PRODUCT_ARCH}.*")

if [ ! -f "${IMAGE}" ]; then
	echo ">> No image found."
	exit 1
fi

echo ">>> Booting image ${IMAGE}..."

TAPDEV=tap0

if ! ifconfig ${TAPDEV}; then
	TAPDEV=$(ifconfig tap create)
fi

kldstat -qm vmm || kldload vmm
bhyveload -m 1024 -d ${IMAGE} vm0
bhyve -c 1 -m 1024 -AHP \
    -s 0:0,hostbridge \
    -s 1:0,virtio-net,${TAPDEV} \
    -s 2:0,ahci-hd,${IMAGE} \
    -s 31,lpc -l com1,stdio \
    vm0 || true
bhyvectl --destroy --vm=vm0
