#!/bin/sh

# Copyright (c) 2014-2018 Franco Fichtner <franco@opnsense.org>
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

SELF=base

. ./common.sh

BASE_SET=$(find ${SETSDIR} -name "base-*-${PRODUCT_ARCH}.txz")

if [ -f "${BASE_SET}" -a -z "${1}" ]; then
	echo ">>> Reusing base set: ${BASE_SET}"
	exit 0
fi

git_branch ${SRCDIR} ${SRCBRANCH} SRCBRANCH
git_describe ${SRCDIR}

MAKE_ARGS="
TARGET_ARCH=${PRODUCT_ARCH}
TARGET=${PRODUCT_TARGET}
SRCCONF=${CONFIGDIR}/src.conf
__MAKE_CONF=
"

# XXX for our RPI2 builds, needs a better place in the long run
MAKE_ARGS="${MAKE_ARGS} UBLDR_LOADADDR=0x2000000"

${ENV_FILTER} make -s -C${SRCDIR} -j${CPUS} buildworld ${MAKE_ARGS} NO_CLEAN=yes
${ENV_FILTER} make -s -C${SRCDIR}/release obj ${MAKE_ARGS}

# reset the distribution directory
BASE_DISTDIR="$(make -C${SRCDIR}/release -V DISTDIR)/${SELF}"
BASE_OBJDIR="$(make -C${SRCDIR}/release -V .OBJDIR)"
setup_stage "${BASE_OBJDIR}/${BASE_DISTDIR}"

# remove older object archives, too
BASE_OBJ=$(make -C${SRCDIR}/release -V .OBJDIR)/base.txz
rm -f ${BASE_OBJ}

${ENV_FILTER} make -s -C${SRCDIR}/release base.txz ${MAKE_ARGS}

sh ./clean.sh ${SELF}

setup_stage ${STAGEDIR} work

echo ">>> Generating kernel set:"

BASE_SET=${SETSDIR}/base-${REPO_VERSION}-${PRODUCT_ARCH}

tar -C ${STAGEDIR}/work -xJpf ${BASE_OBJ}

setup_version ${STAGEDIR} work ${SELF}

tar -C ${STAGEDIR}/work -cvf - . | xz > ${BASE_SET}.txz

echo -n ">>> Generating obsolete file list... "

tar -tf ${BASE_SET}.txz | \
    sed -e 's/^\.//g' -e '/\/$/d' | sort > ${STAGEDIR}/setdiff.new

: > ${STAGEDIR}/setdiff.old
if [ -s ${CONFIGDIR}/plist.base.${PRODUCT_ARCH} ]; then
	cat ${CONFIGDIR}/plist.base.${PRODUCT_ARCH} | \
	    sed -e 's/^\.//g' -e '/\/$/d' | sort > ${STAGEDIR}/setdiff.old
fi

: > ${STAGEDIR}/setdiff.tmp
if [ -s ${CONFIGDIR}/plist.obsolete.${PRODUCT_ARCH} ]; then
	diff -u ${CONFIGDIR}/plist.obsolete.${PRODUCT_ARCH} \
	    ${STAGEDIR}/setdiff.new | grep '^-/' | \
	    cut -b 2- > ${STAGEDIR}/setdiff.tmp
fi

(cat ${STAGEDIR}/setdiff.tmp; diff -u ${STAGEDIR}/setdiff.old \
    ${STAGEDIR}/setdiff.new | grep '^-/' | cut -b 2-) | \
    sort -u > ${BASE_SET}.obsolete

echo "done"

generate_signature ${BASE_SET}.txz
generate_signature ${BASE_SET}.obsolete
