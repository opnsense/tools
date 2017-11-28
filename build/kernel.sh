#!/bin/sh

# Copyright (c) 2014-2017 Franco Fichtner <franco@opnsense.org>
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

SELF=kernel

. ./common.sh

KERNEL_SET=$(find ${SETSDIR} -name "kernel-*-${PRODUCT_ARCH}.txz")

if [ -f "${KERNEL_SET}" -a -z "${1}" ]; then
	echo ">>> Reusing kernel set: ${KERNEL_SET}"
	exit 0
fi

git_branch ${SRCDIR} ${SRCBRANCH} SRCBRANCH
git_describe ${SRCDIR}

KERNEL_DEBUG_SET=${SETSDIR}/kernel-dbg-${REPO_VERSION}-${PRODUCT_ARCH}.txz
KERNEL_RELEASE_SET=${SETSDIR}/kernel-${REPO_VERSION}-${PRODUCT_ARCH}.txz

if [ -f ${CONFIGDIR}/${PRODUCT_KERNEL} ]; then
	cp "${CONFIGDIR}/${PRODUCT_KERNEL}" \
	    "${SRCDIR}/sys/${PRODUCT_TARGET}/conf/${PRODUCT_KERNEL}"
fi

MAKE_ARGS="
TARGET_ARCH=${PRODUCT_ARCH}
TARGET=${PRODUCT_TARGET}
KERNCONF=${PRODUCT_KERNEL}
SRCCONF=${CONFIGDIR}/src.conf
__MAKE_CONF=
"

${ENV_FILTER} make -s -C${SRCDIR} -j${CPUS} buildkernel ${MAKE_ARGS} NO_KERNELCLEAN=yes
${ENV_FILTER} make -s -C${SRCDIR}/release obj ${MAKE_ARGS}

build_marker kernel

KERNEL_OBJ=$(make -C${SRCDIR}/release -V .OBJDIR)/kernel.txz
DEBUG_OBJ=$(make -C${SRCDIR}/release -V .OBJDIR)/kernel-dbg.txz

rm -f ${KERNEL_OBJ} ${DEBUG_OBJ}
${ENV_FILTER} make -s -C${SRCDIR}/release kernel.txz ${MAKE_ARGS}

sh ./clean.sh ${SELF}

if [ -z "$(tar -tf ${DEBUG_OBJ})" ]; then
	echo -n ">>> Copying release kernel set... "
	mv ${KERNEL_OBJ} ${KERNEL_RELEASE_SET}
	echo "done"
	KERNEL_SET=${KERNEL_RELEASE_SET}
else
	setup_stage ${STAGEDIR}
	echo ">>> Generating debug kernel set:"
	tar -C ${STAGEDIR} -xjf ${KERNEL_OBJ}
	tar -C ${STAGEDIR} -xjf ${DEBUG_OBJ}
	tar -C ${STAGEDIR} -cvf - . | xz > ${KERNEL_DEBUG_SET}
	KERNEL_SET=${KERNEL_DEBUG_SET}
fi

rm -f ${KERNEL_OBJ} ${DEBUG_OBJ}
generate_signature ${KERNEL_SET}
