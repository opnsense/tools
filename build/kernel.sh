#!/bin/sh

# Copyright (c) 2014 Franco Fichtner <franco@lastsummer.de>
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

. ./common.sh

mkdir -p ${SETSDIR}
rm -rf ${SETSDIR}/kernel.txz

git_clear ${SRCDIR}

BUILD_KERNEL="SMP"

# XXX move config to src.git
cp ${TOOLSDIR}/config/current/${BUILD_KERNEL} ${SRCDIR}/sys/${TARGET_ARCH}/conf/${BUILD_KERNEL}

MAKEARGS="TARGET_ARCH=${ARCH} KERNCONF=${BUILD_KERNEL}"

make -C${SRCDIR} -j${CPUS} buildkernel ${MAKEARGS} NO_KERNELCLEAN=yes
make -C${SRCDIR}/release obj ${MAKEARGS}
make -C${SRCDIR}/release kernel.txz ${MAKEARGS}

mv $(make -C${SRCDIR}/release -V .OBJDIR)/kernel.txz ${SETSDIR}/kernel.txz
