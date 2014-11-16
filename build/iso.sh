#!/bin/sh

# Copyright (c) 2004-2009 Scott Ullrich
# Copyright (c) 2014 Franco Fichtner <franco@lastsummer.de>
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

. ./common.sh

mkdir -p ${IMAGESDIR}

setup_stage ${STAGEDIR}
setup_base ${STAGEDIR}
setup_kernel ${STAGEDIR}
setup_packages ${STAGEDIR}
setup_platform ${STAGEDIR}
# XXX mtree before platform when core.git is in packages
setup_mtree ${STAGEDIR}

echo -n ">>> Building ISO image... "

mtree -Pcp ${STAGEDIR} | bzip2 -9 > root.dist.bz2
mkdir -p ${STAGEDIR}/dist
mv root.dist.bz2 ${STAGEDIR}/dist/

WORKDIR=/tmp/iso.$$
# must be upper case:
ISOLABEL=LIVECD

mkdir -p ${WORKDIR}/etc
echo "/dev/iso9660/${ISOLABEL} / cd9660 ro 0 0" > ${WORKDIR}/etc/fstab

makefs -t cd9660 -o bootimage="i386;${STAGEDIR}/boot/cdboot" \
    -o no-emul-boot -o label=${ISOLABEL} -o rockridge \
    ${ISOPATH} ${STAGEDIR} ${WORKDIR}

rm -rf ${WORKDIR}

echo "done:"

ls -lah ${IMAGESDIR}/*
