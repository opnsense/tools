#!/bin/sh

# Copyright (c) 2016-2019 Franco Fichtner <franco@opnsense.org>
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

SELF=prefetch

. ./common.sh

git_branch ${SRCDIR} ${SRCBRANCH} SRCBRANCH

ABI="FreeBSD:${SRCREVISION%%.*}:${PRODUCT_ARCH}/${PRODUCT_SETTINGS}"

for ARG in ${@}; do
	case ${ARG} in
	base)
		sh ./clean.sh ${ARG}
		URL="${PRODUCT_MIRROR}/${ABI}/sets/${ARG}-${PRODUCT_VERSION}-${PRODUCT_ARCH}"
		for SUFFIX in txz.sig txz; do
			fetch -o ${SETSDIR} ${URL}.${SUFFIX} || true
		done
		;;
	kernel)
		sh ./clean.sh kernel
		URL="${PRODUCT_MIRROR}/${ABI}/sets/${ARG}-${PRODUCT_VERSION}-${PRODUCT_ARCH}"
		for SUFFIX in txz.sig txz; do
			fetch -o ${SETSDIR} ${URL}.${SUFFIX} || true
		done
		;;
	packages)
		sh ./clean.sh ${ARG}
		URL="${PRODUCT_MIRROR}/${ABI}/sets/${ARG}-${PRODUCT_VERSION}-${PRODUCT_FLAVOUR}-${PRODUCT_ARCH}"
		for SUFFIX in tar.sig tar; do
			fetch -o ${SETSDIR} ${URL}.${SUFFIX} || true
		done
		;;
	esac
done
