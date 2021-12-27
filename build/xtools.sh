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

SELF=xtools

. ./common.sh

if [ -z "${PRODUCT_CROSS}" ]; then
	echo ">>> No need to build xtools on native build"
	exit 0
fi

XTOOLSET=$(find_set xtools)

if [ -f "${XTOOLSET}" -a -z "${1}" ]; then
	echo ">>> Reusing xtools set: ${XTOOLSET}"
	exit 0
fi

git_branch ${SRCDIR} ${SRCBRANCH} SRCBRANCH
git_version ${SRCDIR}

XTOOLSET=${SETSDIR}/xtools-${PRODUCT_VERSION}-${PRODUCT_ARCH}.txz

sh ./clean.sh ${SELF}

setup_stage ${STAGEDIR}

MAKE_ARGS="TARGET_ARCH=${PRODUCT_ARCH} TARGET=${PRODUCT_TARGET}"
MAKE_ARGS="${MAKE_ARGS} SRCCONF=${CONFIGDIR}/src.conf __MAKE_CONF="

${ENV_FILTER} make -C${SRCDIR} -j${CPUS} native-xtools ${MAKE_ARGS} NO_CLEAN=yes

XTOOLS_DIR=$(make -C${SRCDIR} -f Makefile.inc1 -v OBJTREE ${MAKE_ARGS})/nxb-bin

${ENV_FILTER} make -C${SRCDIR} -j${CPUS} native-xtools-install ${MAKE_ARGS} NO_CLEAN=yes DESTDIR=${XTOOLS_DIR}/..

echo -n ">>> Generating xtools set... "

tar -C ${XTOOLS_DIR} -cJf ${XTOOLSET} .

echo "done"
