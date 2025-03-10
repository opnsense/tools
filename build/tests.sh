#!/bin/sh

# Copyright (c) 2024-2025 Franco Fichtner <franco@opnsense.org>
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

SELF=tests

. ./common.sh

TESTSSET=$(find_set tests)

if [ -f "${TESTSSET}" -a -z "${1}" ]; then
	echo ">>> Reusing tests set: ${TESTSSET}"
	exit 0
fi

git_branch ${SRCDIR} ${SRCBRANCH} SRCBRANCH
git_version ${SRCDIR}

TESTSSET=${SETSDIR}/tests-${PRODUCT_VERSION}-${PRODUCT_ARCH}.txz

MAKE_ARGS="
TARGET_ARCH=${PRODUCT_ARCH}
TARGET=${PRODUCT_TARGET}
SRCCONF=${CONFIGDIR}/src.conf
WITHOUT_DEBUG_FILES=yes
__MAKE_CONF=
${MAKE_ARGS_DEV}
"

${ENV_FILTER} make -C${SRCDIR}/lib/libnetbsd -j${CPUS} all ${MAKE_ARGS}
${ENV_FILTER} make -C${SRCDIR}/tests -j${CPUS} all ${MAKE_ARGS}

sh ./clean.sh ${SELF}

setup_stage ${STAGEDIR} work/usr/tests
mtree -deiU -f ${SRCDIR}/etc/mtree/BSD.tests.dist -p ${STAGEDIR}/work/usr/tests

${ENV_FILTER} make -C${SRCDIR}/tests install ${MAKE_ARGS} DESTDIR=${STAGEDIR}/work

generate_set ${STAGEDIR}/work ${TESTSSET}
generate_signature ${TESTSSET}
