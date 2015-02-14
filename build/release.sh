#!/bin/sh

# Copyright (c) 2015 Franco Fichtner <franco@opnsense.org>
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

if [ -n "${1}" ]; then
	# pull in a real release tag
	PRODUCT_VERSION=${1}
fi

. ./common.sh

if [ -n "${1}" ]; then
	# make sure the all-encompassing package is a release, too
	if [ ! -f ${PACKAGESDIR}/${ARCH}/opnsense-${1}.txz ]; then
		echo "Release version mismatch:"
		ls ${PACKAGESDIR}/${ARCH}/opnsense-*.txz
		exit 1
	fi
fi

rm -f ${SETSDIR}/release-*-${ARCH}.tar

echo ">>> Creating packages for ${PRODUCT_VERSION}"

cd ${TOOLSDIR}/build && ./packages.sh

echo ">>> Creating images for ${PRODUCT_VERSION}"

cd ${TOOLSDIR}/build && ./clean.sh images
cd ${TOOLSDIR}/build && ./memstick.sh
cd ${TOOLSDIR}/build && ./iso.sh

setup_stage ${STAGEDIR}

echo ">>> Compressing images for ${PRODUCT_VERSION}"

mv ${IMAGESDIR}/${PRODUCT_NAME}-* ${STAGEDIR}
bzip2 ${STAGEDIR}/${PRODUCT_NAME}-*-cdrom-* &
bzip2 ${STAGEDIR}/${PRODUCT_NAME}-*-serial-* &
bzip2 ${STAGEDIR}/${PRODUCT_NAME}-*-vga-* &
wait
mkdir -p ${STAGEDIR}/tmp

echo ">>> Checksumming images for ${PRODUCT_VERSION}"

cd ${STAGEDIR} && sha256 ${PRODUCT_NAME}-* > tmp/${PRODUCT_NAME}-${PRODUCT_VERSION}-checksums-${ARCH}.sha256
cd ${STAGEDIR} && md5 ${PRODUCT_NAME}-* > tmp/${PRODUCT_NAME}-${PRODUCT_VERSION}-checksums-${ARCH}.md5

mv tmp/* .
rm -rf tmp

echo ">>> Bundling images for ${PRODUCT_VERSION}"

tar -cf ${SETSDIR}/release-${PRODUCT_VERSION}-${ARCH}.tar .
