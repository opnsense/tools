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

. ./common.sh && $(${SCRUB_ARGS})

if [ -n "${1}" ]; then
	# make sure the all-encompassing package is a release, too
	setup_stage ${STAGEDIR}
	extract_packages ${STAGEDIR}
	if [ ! -f ${STAGEDIR}${PACKAGESDIR}/All/opnsense-${1}.txz ]; then
		echo "Release version mismatch:"
		(cd ${STAGEDIR}${PACKAGESDIR}/All; ls opnsense-*.txz)
		exit 1
	fi
fi

sh ./clean.sh release images

echo ">>> Creating images for ${PRODUCT_RELEASE}"

sh ./memstick.sh
sh ./nano.sh
sh ./iso.sh

setup_stage ${STAGEDIR}

echo -n ">>> Compressing images for ${PRODUCT_RELEASE}... "

mv ${IMAGESDIR}/${PRODUCT_RELEASE}-* ${STAGEDIR}
for IMAGE in $(ls ${STAGEDIR}/${PRODUCT_RELEASE}-*); do
	bzip2 ${IMAGE} &
done
wait

echo "done"

echo -n ">>> Checksumming images for ${PRODUCT_RELEASE}... "

mkdir -p ${STAGEDIR}/tmp
cd ${STAGEDIR} && sha256 ${PRODUCT_RELEASE}-* > tmp/${PRODUCT_RELEASE}-checksums-${ARCH}.sha256
cd ${STAGEDIR} && md5 ${PRODUCT_RELEASE}-* > tmp/${PRODUCT_RELEASE}-checksums-${ARCH}.md5

mv tmp/* .
rm -rf tmp

echo "done"

echo -n ">>> Bundling images for ${PRODUCT_RELEASE}... "

tar -cf ${SETSDIR}/release-${PRODUCT_VERSION}_${PRODUCT_FLAVOUR}-${ARCH}.tar .
echo "done"
