#!/bin/sh

# Copyright (c) 2015-2021 Franco Fichtner <franco@opnsense.org>
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

SELF=release

. ./common.sh

RELEASESET=$(find_set release)

if [ -f "${RELEASESET}" -a -z "${1}" ]; then
	echo ">>> Reusing release set: ${RELEASESET}"
	exit 0
fi

RELEASESET="${SETSDIR}/release-${PRODUCT_VERSION}-${PRODUCT_ARCH}.tar"

sh ./clean.sh ${SELF}

setup_stage ${STAGEDIR}

echo -n ">>> Compressing images for ${PRODUCT_RELEASE}... "

for IMAGE in arm dvd nano serial vga vm; do
	sh ./compress.sh ${IMAGE} > /dev/null &
done
wait

echo "done"

for IMAGE in $(find ${IMAGESDIR} -name "${PRODUCT_NAME}-*-${PRODUCT_ARCH}.*.bz2"); do
	cp ${IMAGE} ${STAGEDIR}
done

echo -n ">>> Checksumming images for ${PRODUCT_RELEASE}... "

(cd ${STAGEDIR} && sha256 ${PRODUCT_RELEASE}-*) > ${STAGEDIR}/checksums
mv ${STAGEDIR}/checksums \
    ${STAGEDIR}/${PRODUCT_RELEASE}-checksums-${PRODUCT_ARCH}.sha256

echo "done"

for IMAGE in $(find ${IMAGESDIR} -name "${PRODUCT_NAME}-*-${PRODUCT_ARCH}.*.sig"); do
	cp ${IMAGE} ${STAGEDIR}
done

if [ -f "${PRODUCT_PRIVKEY}" ]; then
	# checked for private key, but want the public key to
	# be able to verify the images on the mirror later on
	cp "${PRODUCT_PUBKEY}" \
	    "${STAGEDIR}/${PRODUCT_NAME}${PRODUCT_SUFFIX}-${PRODUCT_SETTINGS}.pub"
fi

echo -n ">>> Bundling images for ${PRODUCT_RELEASE}... "
tar -C ${STAGEDIR} -cf ${RELEASESET} .
echo "done"
