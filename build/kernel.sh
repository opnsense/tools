#!/bin/sh

# Copyright (c) 2014-2019 Franco Fichtner <franco@opnsense.org>
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

KERNEL_SET=$(find ${SETSDIR} -name "kernel-*-${PRODUCT_ARCH}${PRODUCT_DEVICE+"-${PRODUCT_DEVICE}"}.txz")

if [ -f "${KERNEL_SET}" -a -z "${1}" ]; then
	echo ">>> Reusing kernel set: ${KERNEL_SET}"
	exit 0
fi

git_branch ${SRCDIR} ${SRCBRANCH} SRCBRANCH
git_describe ${SRCDIR}

KERNEL_DEBUG_SET=${SETSDIR}/kernel-dbg-${REPO_VERSION}-${PRODUCT_ARCH}${PRODUCT_DEVICE+"-${PRODUCT_DEVICE}"}.txz
KERNEL_RELEASE_SET=${SETSDIR}/kernel-${REPO_VERSION}-${PRODUCT_ARCH}${PRODUCT_DEVICE+"-${PRODUCT_DEVICE}"}.txz

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
${MAKE_ARGS_DEV}
"

if [ ${PRODUCT_HOST} != ${PRODUCT_ARCH} ]; then
	${ENV_FILTER} make -s -C${SRCDIR} -j${CPUS} kernel-toolchain ${MAKE_ARGS}
fi
${ENV_FILTER} make -s -C${SRCDIR} -j${CPUS} buildkernel ${MAKE_ARGS} NO_KERNELCLEAN=yes
${ENV_FILTER} make -s -C${SRCDIR}/release obj ${MAKE_ARGS}

# reset the distribution directory
KERNEL_DISTDIR="$(make -C${SRCDIR}/release -V DISTDIR ${MAKE_ARGS})/${SELF}"
KERNEL_OBJDIR="$(make -C${SRCDIR}/release -V .OBJDIR ${MAKE_ARGS})"
setup_stage "${KERNEL_OBJDIR}/${KERNEL_DISTDIR}"

# remove older object archives, too
KERNEL_OBJ=$(make -C${SRCDIR}/release -V .OBJDIR ${MAKE_ARGS})/kernel.txz
DEBUG_OBJ=$(make -C${SRCDIR}/release -V .OBJDIR ${MAKE_ARGS})/kernel-dbg.txz
rm -f ${KERNEL_OBJ} ${DEBUG_OBJ}

# We used kernel.txz because we did not rewrite it,
# but as time went on and version info was embedded
# for tighter signature verification handling it is
# a convoluted action, but the archive gives us a
# full update set so we repack it instead of using
# src-related commands here too loosely...
${ENV_FILTER} make -s -C${SRCDIR}/release kernel.txz ${MAKE_ARGS}

sh ./clean.sh ${SELF}

setup_stage ${STAGEDIR} work

echo ">>> Generating kernel set:"

setup_set ${STAGEDIR}/work ${KERNEL_OBJ}

KERNEL_SET=${KERNEL_RELEASE_SET}

if [ -n "$(test -f ${DEBUG_OBJ} && tar -tf ${DEBUG_OBJ})" ]; then
	setup_set ${STAGEDIR}/work ${DEBUG_OBJ}
	KERNEL_SET=${KERNEL_DEBUG_SET}
fi

setup_version ${STAGEDIR} ${STAGEDIR}/work ${SELF}
generate_set ${STAGEDIR}/work ${KERNEL_SET}
generate_signature ${KERNEL_SET}
