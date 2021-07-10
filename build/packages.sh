#!/bin/sh

# Copyright (c) 2019 Franco Fichtner <franco@opnsense.org>
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

SELF=packages

. ./common.sh

AUXLIST=$(
cat ${CONFIGDIR}/aux.conf | while read PORT_ORIGIN PORT_IGNORE; do
	eval PORT_ORIGIN=${PORT_ORIGIN}
	if [ "$(echo ${PORT_ORIGIN} | colrm 2)" = "#" ]; then
		continue
	fi
	if [ -n "${PORT_IGNORE}" ]; then
		for PORT_QUIRK in $(echo ${PORT_IGNORE} | tr ',' ' '); do
			if [ ${PORT_QUIRK} = ${PRODUCT_TARGET} -o \
			     ${PORT_QUIRK} = ${PRODUCT_ARCH} -o \
			     ${PORT_QUIRK} = ${PRODUCT_FLAVOUR} ]; then
				continue 2
			fi
		done
	fi
	echo ${PORT_ORIGIN}
done
)

setup_stage ${STAGEDIR}
setup_base ${STAGEDIR}
extract_packages ${STAGEDIR}

# The goal for aux packages is that they are part of the packages
# set for nightly builds until they are officially built using the
# "packages" target in which case the only thing that needs to be
# done is stripping the auxiliary packages that are only needed for
# the build and further testing.  Small lookup and delete code...
for AUX in ${AUXLIST}; do
	for PKG in $(cd ${STAGEDIR}; find .${PACKAGESDIR}/All -type f); do
		PKGORIGIN=$(pkg -c ${STAGEDIR} info -F ${PKG} | \
		    grep ^Origin | awk '{ print $3; }')

		if [ "${AUX}" = "${PKGORIGIN}" ]; then
			rm -f ${STAGEDIR}/${PKG}
			break;
		fi
	done
done

bundle_packages ${STAGEDIR} ${SELF}
