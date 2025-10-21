#!/bin/sh

# Copyright (c) 2022 Franco Fichtner <franco@opnsense.org>
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

eval "$(make print-PRODUCT_ARCH,PRODUCT_CORE,PRODUCT_ZFS,SETSDIR 2> /dev/null)"

PACKAGESET=$(find ${SETSDIR} -name "packages-*-${PRODUCT_ARCH}.tar")

if [ ! -f "${PACKAGESET}" ]; then
	echo ">>> Cannot continue without packages set"
	exit 1
fi

COREFILE=$(tar -tf ${PACKAGESET} | grep -x "\./All/${PRODUCT_CORE}-[0-9].*\.pkg")

if [ -z "${COREFILE}" ]; then
	echo ">>> Cannot continue without core package: ${PRODUCT_CORE}"
	exit 1
fi

COREFILE=$(basename ${COREFILE%%.pkg})

FS=ufs
if [ -n "${PRODUCT_ZFS}" ]; then
	FS=zfs
fi

make vm-raw,4G,never,serial compress-vm VERSION=${COREFILE##*-}-${FS}
