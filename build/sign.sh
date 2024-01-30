#!/bin/sh

# Copyright (c) 2016-2024 Franco Fichtner <franco@opnsense.org>
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

SELF=sign

. ./common.sh

VERSIONDIR="/usr/local/opnsense/version"

for ARG in ${@}; do
	case ${ARG} in
	base)
		BASESET=$(find_set base)
		if [ -f "${BASESET}" ]; then
			setup_stage ${STAGEDIR}
			setup_set ${STAGEDIR} ${BASESET}
			generate_signature ${STAGEDIR}${VERSIONDIR}/base.mtree
			rm ${BASESET}
			generate_set ${STAGEDIR} ${BASESET}
			generate_signature ${BASESET}
		fi
		;;
	kernel)
		KERNELSET=$(find_set kernel)
		if [ -f "${KERNELSET}" ]; then
			setup_stage ${STAGEDIR}
			setup_set ${STAGEDIR} ${KERNELSET}
			generate_signature ${STAGEDIR}${VERSIONDIR}/kernel.mtree
			rm ${KERNELSET}
			generate_set ${STAGEDIR} ${KERNELSET}
			generate_signature ${KERNELSET}
		fi
		;;
	packages)
		PACKAGESET=$(find_set packages)
		if [ -f "${PACKAGESET}" ]; then
			setup_stage ${STAGEDIR}
			extract_packages ${STAGEDIR}
			bundle_packages ${STAGEDIR}
		fi
		;;
	release)
		RELEASESET=$(find_set release)
		if [ -f "${RELEASESET}" ]; then
			setup_stage ${STAGEDIR}
			setup_set ${STAGEDIR} ${RELEASESET}
			for FILE in $(find ${STAGEDIR} -name "*.sha256" -o \
			    -name "*.pub"); do
				sign_image ${FILE}
			done
			rm ${RELEASESET}
			tar -C ${STAGEDIR} -cf ${RELEASESET} .
		fi
	esac
done
