#!/bin/sh

# Copyright (c) 2014 Franco Fichtner <franco@opnsense.org>
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

PORT_LIST=$(cat ${TOOLSDIR}/config/current/ports)

git_clear ${PORTSDIR}

setup_stage ${STAGEDIR}
setup_base ${STAGEDIR}
setup_chroot ${STAGEDIR}

echo ">>> Setting up ports in ${STAGEDIR}"

MAKE_CONF="${TOOLSDIR}/config/current/make.conf"
if [ -f ${MAKE_CONF} ]; then
	cp ${MAKE_CONF} ${STAGEDIR}/etc/make.conf
fi

tar -C/ -cf - --exclude=.${PORTSDIR}/.git .${PORTSDIR} | \
    tar -C${STAGEDIR} -pxf -

echo ">>> Setting up src in ${STAGEDIR}"

tar -C/ -cf - --exclude=.${SRCDIR}/.git .${SRCDIR} | \
    tar -C${STAGEDIR} -pxf -

# bootstrap all available packages to save time
mkdir -p ${PACKAGESDIR} ${STAGEDIR}${PACKAGESDIR}
cp ${PACKAGESDIR}/* ${STAGEDIR}${PACKAGESDIR} || true

for PACKAGE in "${PORT_LIST}"; do
	PACKAGEFILE=$(ls ${PACKAGESDIR}/${PACKAGE}-*.txz)
	if [ -f "${PACKAGEFILE}" ]; then
		# may fail for missing dependencies and
		# that's what we need: rebuild chain  :)
		pkg -c ${STAGEDIR} add ${PACKAGEFILE} || true
	fi
done

rm -rf ${STAGEDIR}${PACKAGESDIR}/*

echo ">>> Building packages..."

chroot ${STAGEDIR} /bin/sh -es <<EOF || true
if pkg -N; then
	# no need to rebuild
else
	make -C ${PORTSDIR}/ports-mgmt/pkg rmconfig-recursive
	make -C ${PORTSDIR}/ports-mgmt/pkg clean all install
fi

echo "${PORT_LIST}" | {
while read PORT_NAME PORT_CAT PORT_OPT; do
	if [ "\${PORT_NAME}" = "#" ]; then
		continue
	fi

	echo -n ">>> Building \${PORT_NAME}... "

	if pkg query %n \${PORT_NAME} > /dev/null; then
		echo "skipped."
		continue
	fi

	# user configs linger somewhere else and override the override  :(
	make -C ${PORTSDIR}/\${PORT_CAT}/\${PORT_NAME} rmconfig-recursive
	make -C ${PORTSDIR}/\${PORT_CAT}/\${PORT_NAME} clean all install

	if pkg query %n \${PORT_NAME} > /dev/null; then
		# ok
	else
		echo "\${PORT_NAME}: package names don't match"
		exit 1
	fi
done
}
EOF

echo ">>> Creating binary packages..."

chroot ${STAGEDIR} /bin/sh -es <<EOF || true
pkg_resolve_deps()
{
	local PORTS
	local DEPS
	local PORT
	local DEP

	DEPS="\$(pkg info -qd \${1})"
	PORTS="\${1} \${DEPS}"

	for DEP in \${DEPS}; do
		# recurse into hell and back
		pkg_resolve_deps \${DEP}
	done

	for PORT in \${PORTS}; do
		pkg create -no ${PACKAGESDIR} -f txz \${PORT}
	done
}

pkg_resolve_deps pkg

echo "${PORT_LIST}" | {
while read PORT_NAME PORT_CAT PORT_OPT; do
	if [ "\${PORT_NAME}" = "#" ]; then
		continue
	fi

	pkg_resolve_deps "\$(pkg info -E \${PORT_NAME})"
done
}
EOF

rm -rf ${PACKAGESDIR}/*
mv ${STAGEDIR}${PACKAGESDIR}/* ${PACKAGESDIR}

# also build the meta-package
cd ${TOOLSDIR}/build && ./core.sh

# bundle all packages into a ready-to-use set
cd ${TOOLSDIR}/build && ./packages.sh
