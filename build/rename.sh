#!/bin/sh

# Copyright (c) 2016-2017 Franco Fichtner <franco@opnsense.org>
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

SELF=rename

. ./common.sh

for ARG in ${@}; do
	case ${ARG} in
	base)
		setup_stage ${STAGEDIR}
		echo ">>> Repacking base set..."
		BASE_SET=$(find ${SETSDIR} -name "base-*-${PRODUCT_ARCH}.txz")
		tar -C ${STAGEDIR} -xjf ${BASE_SET}
		echo ${VERSION}-${PRODUCT_ARCH} > \
		    ${STAGEDIR}/usr/local/opnsense/version/base
		rm ${BASE_SET}
		tar -C ${STAGEDIR} -cvf - . | xz > ${BASE_SET}
		generate_signature ${BASE_SET}
		echo ">>> Renaming base set: ${VERSION}"
		for FILE in $(find ${SETSDIR} -name \
		    "base-*-${PRODUCT_ARCH}.*"); do
			mv ${FILE} ${SETSDIR}/base-${VERSION}-${FILE##*-}
		done
		;;
	distfiles)
		echo ">>> Renaming distfiles set: ${VERSION}"
		mv ${SETSDIR}/distfiles-*.tar \
		    ${SETSDIR}/distfiles-${VERSION}.tar
		;;
	dvd)
		echo ">>> Renaming dvd image: ${VERSION}"
		mv ${IMAGESDIR}/*-${PRODUCT_FLAVOUR}-dvd-${PRODUCT_ARCH}.iso \
		    ${IMAGESDIR}/${PRODUCT_NAME}-${VERSION}-${PRODUCT_FLAVOUR}-dvd-${PRODUCT_ARCH}.iso
		;;
	kernel)
		setup_stage ${STAGEDIR}
		echo ">>> Repacking kernel set..."
		KERNEL_SET=$(find ${SETSDIR} -name "kernel-*-${PRODUCT_ARCH}.txz")
		tar -C ${STAGEDIR} -xjf ${KERNEL_SET}
		echo ${VERSION}-${PRODUCT_ARCH} > \
		    ${STAGEDIR}/usr/local/opnsense/version/kernel
		rm ${KERNEL_SET}
		tar -C ${STAGEDIR} -cvf - . | xz > ${KERNEL_SET}
		generate_signature ${KERNEL_SET}
		echo ">>> Renaming kernel set: ${VERSION}"
		for FILE in $(find ${SETSDIR} -name \
		    "kernel-*-${PRODUCT_ARCH}.*"); do
			mv ${FILE} ${SETSDIR}/kernel-${VERSION}-${FILE##*-}
		done
		;;
	nano)
		echo ">>> Renaming nano image: ${VERSION}"
		mv ${IMAGESDIR}/*-${PRODUCT_FLAVOUR}-nano-${PRODUCT_ARCH}.img \
		    ${IMAGESDIR}/${PRODUCT_NAME}-${VERSION}-${PRODUCT_FLAVOUR}-nano-${PRODUCT_ARCH}.img
		;;
	packages)
		echo ">>> Renaming packages set: ${VERSION}"
		for FILE in $(find ${SETSDIR} -name \
		    "packages-*-${PRODUCT_FLAVOUR}-${PRODUCT_ARCH}.*"); do
			mv ${FILE} ${SETSDIR}/packages-${VERSION}-${PRODUCT_FLAVOUR}-${FILE##*-}
		done
		;;
	serial)
		echo ">>> Renaming serial image: ${VERSION}"
		mv ${IMAGESDIR}/*-${PRODUCT_FLAVOUR}-serial-${PRODUCT_ARCH}.img \
		    ${IMAGESDIR}/${PRODUCT_NAME}-${VERSION}-${PRODUCT_FLAVOUR}-serial-${PRODUCT_ARCH}.img
		;;
	vga)
		echo ">>> Renaming vga image: ${VERSION}"
		mv ${IMAGESDIR}/*-${PRODUCT_FLAVOUR}-vga-${PRODUCT_ARCH}.img \
		    ${IMAGESDIR}/${PRODUCT_NAME}-${VERSION}-${PRODUCT_FLAVOUR}-vga-${PRODUCT_ARCH}.img
		;;
	vm)
		echo ">>> Renaming vm set: ${VERSION}"
		for FILE in $(find ${SETSDIR} -name \
		    "*-${PRODUCT_FLAVOUR}-vm-${PRODUCT_ARCH}.*"); do
			mv ${FILE} ${SETSDIR}/${PRODUCT_NAME}-${VERSION}-${PRODUCT_FLAVOUR}-vm-${FILE##*-}
		done
		;;
	esac
done
