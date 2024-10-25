#!/bin/sh

# Copyright (c) 2024 Franco Fichtner <franco@opnsense.org>
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

SELF=kyua

. ./common.sh

KYUASET=$(find_set kyua)

if [ -f "${KYUASET}" -a -z "${1}" ]; then
	echo ">>> Reusing kyua set: ${KYUASET}"
	exit 0
fi

git_branch ${SRCDIR} ${SRCBRANCH} SRCBRANCH
git_version ${SRCDIR}

KYUASET=${SETSDIR}/kyua-${PRODUCT_VERSION}-${PRODUCT_ARCH}.txz

COMPONENTS="
lib/atf
libexec/atf
lib/liblutok
lib/liblua
usr.bin/kyua
lib/libnetbsd
tests
"

for COMPONENT in ${COMPONENTS}; do
	make -sC ${SRCDIR}/${COMPONENT} clean
done

for COMPONENT in ${COMPONENTS}; do
	echo -n ">>> Building ${COMPONENT}... "
	make -sC ${SRCDIR}/${COMPONENT} all
	echo "done."
done

setup_stage ${STAGEDIR} work/usr/tests work/usr/include

mtree -deiU -f ${SRCDIR}/etc/mtree/BSD.usr.dist -p ${STAGEDIR}/work/usr
mtree -deiU -f ${SRCDIR}/etc/mtree/BSD.tests.dist -p ${STAGEDIR}/work/usr/tests
mtree -deiU -f ${SRCDIR}/etc/mtree/BSD.include.dist -p ${STAGEDIR}/work/usr/include

for COMPONENT in ${COMPONENTS}; do
	if [ -n "${COMPONENT##lib/*}" -o "${COMPONENT}" = "lib/atf" ]; then
		make -sC ${SRCDIR}/${COMPONENT} \
		    DESTDIR=${STAGEDIR}/work install
	fi
done

# remove a couple of debug additions
rm -rf ${STAGEDIR}/work/usr/lib/debug
find ${STAGEDIR}/work -type f -name "*.debug" -delete
find ${STAGEDIR}/work -type d -empty -delete

sh ./clean.sh ${SELF}

setup_version ${STAGEDIR} ${STAGEDIR}/work ${SELF}
generate_set ${STAGEDIR}/work ${KYUASET}
