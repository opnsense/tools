#!/bin/sh

# Copyright (c) 2014-2020 Franco Fichtner <franco@opnsense.org>
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

SELF=clean

. ./common.sh

for ARG in ${@}; do
	case ${ARG} in
	arm)
		echo ">>> Removing arm image"
		rm -f ${IMAGESDIR}/*-${PRODUCT_FLAVOUR}-arm-${PRODUCT_ARCH}-${PRODUCT_DEVICE}.img*
		;;
	base)
		echo ">>> Removing base set"
		rm -f ${SETSDIR}/base-*-${PRODUCT_ARCH}${PRODUCT_DEVICE+"-${PRODUCT_DEVICE}"}.*
		;;
	core)
		echo ">>> Removing core from packages set"
		setup_stage ${STAGEDIR}
		setup_base ${STAGEDIR}
		if extract_packages ${STAGEDIR}; then
			remove_packages ${STAGEDIR} ${PRODUCT_CORES}
			bundle_packages ${STAGEDIR} '' core
		fi
		;;
	distfiles)
		echo ">>> Removing distfiles set"
		rm -f ${SETSDIR}/distfiles-*.tar
		;;
	dvd)
		echo ">>> Removing dvd image"
		rm -f ${IMAGESDIR}/*-${PRODUCT_FLAVOUR}-dvd-${PRODUCT_ARCH}.iso*
		;;
	images)
		setup_stage ${IMAGESDIR}
		;;
	kernel)
		echo ">>> Removing kernel set"
		rm -f ${SETSDIR}/kernel-*-${PRODUCT_ARCH}${PRODUCT_DEVICE+"-${PRODUCT_DEVICE}"}.*
		;;
	logs)
		setup_stage ${LOGSDIR}
		;;
	nano)
		echo ">>> Removing nano image"
		rm -f ${IMAGESDIR}/*-${PRODUCT_FLAVOUR}-nano-${PRODUCT_ARCH}.img*
		;;
	obj)
		if [ -d ${STAGEDIRPREFIX}${TOOLSDIR} ]; then
			for DIR in $(find ${STAGEDIRPREFIX}${TOOLSDIR} \
			    -type d -depth 3); do
				setup_stage ${DIR}
			done
		fi
		for DIR in $(find /usr/obj -type d -depth 1); do
			setup_stage ${DIR}
			rm -rf ${DIR}
		done
		;;
	packages|ports)
		echo ">>> Removing packages set"
		rm -f ${SETSDIR}/packages-*-${PRODUCT_FLAVOUR}-${PRODUCT_ARCH}.*
		;;
	plugins)
		echo ">>> Removing plugins from packages set"
		setup_stage ${STAGEDIR}
		setup_base ${STAGEDIR}
		if extract_packages ${STAGEDIR}; then
			remove_packages ${STAGEDIR} ${PRODUCT_PLUGINS}
			bundle_packages ${STAGEDIR} '' plugins
		fi
		;;
	release)
		echo ">>> Removing release set"
		rm -f ${SETSDIR}/release-*-${PRODUCT_FLAVOUR}-${PRODUCT_ARCH}.tar
		;;
	serial)
		echo ">>> Removing serial image"
		rm -f ${IMAGESDIR}/*-${PRODUCT_FLAVOUR}-serial-${PRODUCT_ARCH}.img*
		;;
	sets)
		setup_stage ${SETSDIR}
		;;
	stage)
		setup_stage ${STAGEDIR}
		;;
	src)
		setup_stage /usr/obj${SRCDIR}
		;;
	vga)
		echo ">>> Removing vga image"
		rm -f ${IMAGESDIR}/*-${PRODUCT_FLAVOUR}-vga-${PRODUCT_ARCH}.img*
		;;
	vm)
		echo ">>> Removing vm image"
		rm -f ${IMAGESDIR}/*-${PRODUCT_FLAVOUR}-vm-${PRODUCT_ARCH}.*
		;;
	xtools)
		echo ">>> Removing xtools set"
		rm -f ${SETSDIR}/xtools-*-${PRODUCT_ARCH}.*
		;;
	esac
done
