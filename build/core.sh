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

. ./common.sh && $(${SCRUB_ARGS})

git_describe ${COREDIR}

setup_stage ${STAGEDIR}
setup_base ${STAGEDIR}
setup_clone ${STAGEDIR} ${COREDIR}
setup_clone ${STAGEDIR} ${PORTSDIR}

while read PORT_NAME PORT_CAT PORT_OPT; do
	if [ "$(echo ${PORT_NAME} | colrm 2)" = "#" -o -n "${PORT_OPT}" ]; then
		continue
	fi

	PORT_LIST="${PORT_LIST} ${PORT_NAME}"
done < ${PRODUCT_CONFIG}/ports.conf

extract_packages ${STAGEDIR} opnsense
install_packages ${STAGEDIR} gettext-tools ${PORT_LIST}

chroot ${STAGEDIR} /bin/sh -es << EOF
mkdir -p ${STAGEDIR}
make -C ${COREDIR} DESTDIR=${STAGEDIR} install > ${STAGEDIR}/plist

for PKGFILE in \$(ls \${STAGEDIR}/+*); do
	# fill in the blanks that come from the build
	sed -i "" -e "s/%%REPO_VERSION%%/${REPO_VERSION}/g" \${PKGFILE}
	sed -i "" -e "s/%%REPO_COMMENT%%/${REPO_COMMENT}/g" \${PKGFILE}
done

REPO_FLAVOUR="latest"
if [ ${PRODUCT_FLAVOUR} = "LibreSSL" ]; then
	REPO_FLAVOUR="libressl"
fi
sed -i '' -e "s/%%REPO_FLAVOUR%%/\${REPO_FLAVOUR}/g" \
    ${STAGEDIR}${CONFIG_PKG}

for PORT_NAME in ${PORT_LIST}; do
	echo -n ">>> Collecting depencency for \${PORT_NAME}... "
	# catch dependecy error in shell execution
	PORT_DEP=\$(pkg query '%n: { version: "%v", origin: "%o" }' \${PORT_NAME})
	echo "done"

	# fill in the direct ports dependencies
	echo "  \${PORT_DEP}" >> ${STAGEDIR}/deps
done

# remove placeholder now that all dependencies are in place
sed -i "" -e "/%%REPO_DEPENDS%%/r ${STAGEDIR}/deps" ${STAGEDIR}/+MANIFEST
sed -i "" -e '/%%REPO_DEPENDS%%/d' ${STAGEDIR}/+MANIFEST

echo -n ">>> Creating custom package for ${COREDIR}... "
pkg create -m ${STAGEDIR} -r ${STAGEDIR} -p ${STAGEDIR}/plist -o ${PACKAGESDIR}/All
echo "done"
EOF

bundle_packages ${STAGEDIR}
