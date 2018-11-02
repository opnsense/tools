#!/bin/sh

# Copyright (c) 2016-2018 Franco Fichtner <franco@opnsense.org>
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
		    "*-${PRODUCT_FLAVOUR}-arm-${PRODUCT_ARCH}.*"); do
		    mv ${FILE} ${IMAGESDIR}/${PRODUCT_NAME}${PRODUCT_SUFFIX}-${PRODUCT_VERSION}-${PRODUCT_FLAVOUR}-arm-${FILE##*-}
		done
		;;
	base)
		setup_stage ${STAGEDIR} work
		echo ">>> Repacking base set..."
		BASE_SET=$(find ${SETSDIR} -name "base-*-${PRODUCT_ARCH}.txz")
		setup_set ${STAGEDIR}/work ${BASE_SET}
		cp ${STAGEDIR}/work/usr/local/opnsense/version/base.obsolete \
		    ${STAGEDIR}/obsolete
		REPO_VERSION=${PRODUCT_VERSION}
		setup_version ${STAGEDIR} ${STAGEDIR}/work ${ARG} ${STAGEDIR}/obsolete
		rm ${BASE_SET}
		generate_set ${STAGEDIR}/work ${BASE_SET}
		generate_signature ${BASE_SET}
		echo ">>> Renaming base set: ${PRODUCT_VERSION}"
		for FILE in $(find ${SETSDIR} -name \
		    "base-*-${PRODUCT_ARCH}.*"); do
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
		KERNEL_SET=$(find ${SETSDIR} -name "kernel-*-${PRODUCT_ARCH}.txz")
		setup_set ${STAGEDIR}/work ${KERNEL_SET}
		REPO_VERSION=${PRODUCT_VERSION}
		setup_version ${STAGEDIR} ${STAGEDIR}/work ${ARG}
		rm ${KERNEL_SET}
		generate_set ${STAGEDIR}/work ${KERNEL_SET}
		generate_signature ${KERNEL_SET}
		echo ">>> Renaming kernel set: ${PRODUCT_VERSION}"
		for FILE in $(find ${SETSDIR} -name \
		    "kernel-*-${PRODUCT_ARCH}.*"); do
			mv ${FILE} ${SETSDIR}/kernel-${PRODUCT_VERSION}-${FILE##*-}
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
		for FILE in $(find ${SETSDIR} -name \
		    "*-${PRODUCT_FLAVOUR}-vm-${PRODUCT_ARCH}.*"); do
			mv ${FILE} ${SETSDIR}/${PRODUCT_NAME}${PRODUCT_SUFFIX}-${PRODUCT_VERSION}-${PRODUCT_FLAVOUR}-vm-${FILE##*-}
		done
		;;
	esac
done
