#!/bin/sh

# Copyright (c) 2014-2015 Franco Fichtner <franco@opnsense.org>
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

rm -f ${PACKAGESDIR}/${ARCH}/opnsense-*.txz

git_clear ${COREDIR}
git_describe ${COREDIR}

setup_stage ${STAGEDIR}
setup_base ${STAGEDIR}
setup_packages ${STAGEDIR}

# no compiling needed; simply install
make -C ${COREDIR} DESTDIR=${STAGEDIR} install > ${STAGEDIR}/plist

for PKGFILE in $(ls ${STAGEDIR}/+*); do
	# fill in the blanks that come from the build
	sed -i "" -e "s/%%REPO_VERSION%%/${REPO_VERSION}/g" ${PKGFILE}
	sed -i "" -e "s/%%REPO_COMMENT%%/${REPO_COMMENT}/g" ${PKGFILE}
done

while read PORT_NAME PORT_CAT PORT_OPT; do
	if [ "$(echo ${PORT_NAME} | colrm 2)" = "#" -o -n "${PORT_OPT}" ]; then
		continue
	fi

	# fill in the direct ports dependencies

	cat >> ${STAGEDIR}/deps << EOF
  $(pkg -c ${STAGEDIR} query '%n: { version: "%v", origin: "%o" }' ${PORT_NAME})
EOF
done < ${TOOLSDIR}/config/current/ports.conf

# remove placeholder now that all dependencies are in place
sed -i "" -e "/%%REPO_DEPENDS%%/r ${STAGEDIR}/deps" ${STAGEDIR}/+MANIFEST
sed -i "" -e '/%%REPO_DEPENDS%%/d' ${STAGEDIR}/+MANIFEST

echo -n ">>> Creating custom package for ${COREDIR}... "

pkg -c ${STAGEDIR} create -m / -r / -p /plist -o ${PACKAGESDIR}/${ARCH}
mv ${STAGEDIR}${PACKAGESDIR}/${ARCH}/opnsense-*.txz ${PACKAGESDIR}/${ARCH}

echo "done"
