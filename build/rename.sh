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

SELF=rename

. ./common.sh

for ARG in ${@}; do
	case ${ARG} in
	arm)
		echo ">>> Renaming arm image: ${PRODUCT_VERSION}"
		for FILE in $(find ${IMAGESDIR} -name \
		    "*-${PRODUCT_FLAVOUR}-arm-${PRODUCT_ARCH}-${PRODUCT_DEVICE}.*"); do
		    mv ${FILE} ${IMAGESDIR}/${PRODUCT_NAME}${PRODUCT_SUFFIX}-${PRODUCT_VERSION}-${PRODUCT_FLAVOUR}-arm-${FILE##*-arm-}
		done
		;;
	base)
		setup_stage ${STAGEDIR} work
		echo ">>> Repacking base set..."
		BASESET=$(find_set base)
		setup_set ${STAGEDIR}/work ${BASESET}
		cp ${STAGEDIR}/work/usr/local/opnsense/version/base.obsolete \
		    ${STAGEDIR}/obsolete
		setup_version ${STAGEDIR} ${STAGEDIR}/work ${ARG} ${STAGEDIR}/obsolete
		rm ${BASESET}
		generate_set ${STAGEDIR}/work ${BASESET}
		generate_signature ${BASESET}
		echo ">>> Renaming base set: ${PRODUCT_VERSION}"
		for FILE in $(find ${SETSDIR} -name \
		    "base-*-${PRODUCT_ARCH}${PRODUCT_DEVICE+"-${PRODUCT_DEVICE}"}.*"); do
			# XXX likely doesn't work for PRODUCT_DEVICE
			mv ${FILE} ${SETSDIR}/base-${PRODUCT_VERSION}-${FILE##*-}
		done
		;;
	distfiles)
		echo ">>> Renaming distfiles set: ${PRODUCT_VERSION}"
		mv ${SETSDIR}/distfiles-*.tar \
		    ${SETSDIR}/distfiles-${PRODUCT_VERSION}.tar
		;;
	dvd)
		echo ">>> Renaming dvd image: ${PRODUCT_VERSION}"
		for FILE in $(find ${IMAGESDIR} -name \
		    "*-${PRODUCT_FLAVOUR}-dvd-${PRODUCT_ARCH}.*"); do
		    mv ${FILE} ${IMAGESDIR}/${PRODUCT_NAME}${PRODUCT_SUFFIX}-${PRODUCT_VERSION}-${PRODUCT_FLAVOUR}-dvd-${FILE##*-}
		done
		;;
	kernel)
		setup_stage ${STAGEDIR} work
		echo ">>> Repacking kernel set..."
		KERNELSET=$(find_set kernel-dbg)
		KERNEL_NAME="kernel-dbg"
		if [ -z "${KERNELSET}" ]; then
			KERNELSET=$(find_set kernel)
			KERNEL_NAME="kernel"
		fi
		setup_set ${STAGEDIR}/work ${KERNELSET}
		setup_version ${STAGEDIR} ${STAGEDIR}/work ${ARG}
		rm ${KERNELSET}
		generate_set ${STAGEDIR}/work ${KERNELSET}
		generate_signature ${KERNELSET}
		echo ">>> Renaming kernel set: ${PRODUCT_VERSION}"
		for FILE in $(find ${SETSDIR} -name \
		    "kernel-*-${PRODUCT_ARCH}${PRODUCT_DEVICE+"-${PRODUCT_DEVICE}"}.*"); do
			# XXX likely doesn't work for PRODUCT_DEVICE
			mv ${FILE} ${SETSDIR}/${KERNEL_NAME}-${PRODUCT_VERSION}-${FILE##*-}
		done
		;;
	nano)
		echo ">>> Renaming nano image: ${PRODUCT_VERSION}"
		for FILE in $(find ${IMAGESDIR} -name \
		    "*-${PRODUCT_FLAVOUR}-nano-${PRODUCT_ARCH}.*"); do
		    mv ${FILE} ${IMAGESDIR}/${PRODUCT_NAME}${PRODUCT_SUFFIX}-${PRODUCT_VERSION}-${PRODUCT_FLAVOUR}-nano-${FILE##*-}
		done
		;;
	packages)
		echo ">>> Renaming packages set: ${PRODUCT_VERSION}"
		for FILE in $(find ${SETSDIR} -name \
		    "packages-*-${PRODUCT_FLAVOUR}-${PRODUCT_ARCH}.*"); do
			mv ${FILE} ${SETSDIR}/packages-${PRODUCT_VERSION}-${PRODUCT_FLAVOUR}-${FILE##*-}
		done
		;;
	serial)
		echo ">>> Renaming serial image: ${PRODUCT_VERSION}"
		for FILE in $(find ${IMAGESDIR} -name \
		    "*-${PRODUCT_FLAVOUR}-serial-${PRODUCT_ARCH}.*"); do
		    mv ${FILE} ${IMAGESDIR}/${PRODUCT_NAME}${PRODUCT_SUFFIX}-${PRODUCT_VERSION}-${PRODUCT_FLAVOUR}-serial-${FILE##*-}
		done
		;;
	vga)
		echo ">>> Renaming vga image: ${PRODUCT_VERSION}"
		for FILE in $(find ${IMAGESDIR} -name \
		    "*-${PRODUCT_FLAVOUR}-vga-${PRODUCT_ARCH}.*"); do
		    mv ${FILE} ${IMAGESDIR}/${PRODUCT_NAME}${PRODUCT_SUFFIX}-${PRODUCT_VERSION}-${PRODUCT_FLAVOUR}-vga-${FILE##*-}
		done
		;;
	vm)
		echo ">>> Renaming vm set: ${PRODUCT_VERSION}"
		for FILE in $(find ${IMAGESDIR} -name \
		    "*-${PRODUCT_FLAVOUR}-vm-${PRODUCT_ARCH}.*"); do
			mv ${FILE} ${IMAGESDIR}/${PRODUCT_NAME}${PRODUCT_SUFFIX}-${PRODUCT_VERSION}-${PRODUCT_FLAVOUR}-vm-${FILE##*-}
		done
		;;
	esac
done
