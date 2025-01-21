#!/bin/sh

# Copyright (c) 2015-2025 Franco Fichtner <franco@opnsense.org>
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

SELF=distfiles

. ./common.sh

PORTSLIST=$(list_packages "${PORTSLIST}" ${CONFIGDIR}/aux.conf ${CONFIGDIR}/ports.conf)

git_branch ${SRCDIR} ${SRCBRANCH} SRCBRANCH
git_branch ${PORTSDIR} ${PORTSBRANCH} PORTSBRANCH
git_version ${PORTSDIR}

setup_stage ${STAGEDIR}
setup_base ${STAGEDIR}
setup_clone ${STAGEDIR} ${PORTSDIR}
setup_clone ${STAGEDIR} ${SRCDIR}
setup_chroot ${STAGEDIR}
setup_distfiles ${STAGEDIR}

extract_packages ${STAGEDIR} || true

sh ./make.conf.sh > ${STAGEDIR}/etc/make.conf

echo ">>> Fetching distfiles..."

# block SIGINT to allow for collecting port progress (use with care)
trap : 2

if ! ${ENV_FILTER} chroot ${STAGEDIR} /bin/sh -es << EOF; then PORTSLIST=; fi
MAKE_ARGS="
PACKAGES=${PACKAGESDIR}
PRODUCT_ABI=${PRODUCT_ABI}
TRYBROKEN=yes
UNAME_r=\$(freebsd-version)
USE_PACKAGE_DEPENDS=yes
"
echo "${PORTSLIST}" | while read PORT_ORIGIN; do
	echo ">>> Fetching \${PORT_ORIGIN}..."
	FLAVOR=\${PORT_ORIGIN##*@}
	FLAVOR_ARG=
	if [ "\${FLAVOR}" != "\${PORT_ORIGIN}" ]; then
		FLAVOR_ARG="FLAVOR=\${FLAVOR}"
	fi
	PORT=\${PORT_ORIGIN%%@*}
	if ! make -C ${PORTSDIR}/\${PORT} fetch \${MAKE_ARGS} \${FLAVOR_ARG}; then
		if [ -n "${PRODUCT_REBUILD}" ]; then
			exit 1
		fi
		echo ">>> Failed fetching \${PORT}" >> ${STAGEDIR}/.pkg-msg
	fi
	PORT_DEPENDS=\$(make -C ${PORTSDIR}/\${PORT} all-depends-list \
	    \${MAKE_ARGS})
	for PORT_DEPEND in \${PORT_DEPENDS}; do
		FLAVOR=\${PORT_DEPEND##*@}
		FLAVOR_ARG=
		if [ "\${FLAVOR}" != "\${PORT_DEPEND}" ]; then
			FLAVOR_ARG="FLAVOR=\${FLAVOR}"
		fi
		PORT=\${PORT_DEPEND%%@*}
		if ! make -C \${PORT} fetch \${MAKE_ARGS} \${FLAVOR_ARG}; then
			if [ -n "${PRODUCT_REBUILD}" ]; then
				exit 1
			fi
			echo ">>> Failed fetching \${PORT}" >> ${STAGEDIR}/.pkg-msg
		fi
	done
done
EOF

# unblock SIGINT
trap - 2

sh ./clean.sh ${SELF}

echo -n ">>> Creating distfiles set... "
tar -C ${STAGEDIR}${PORTSDIR} -cf \
    ${SETSDIR}/distfiles-${PRODUCT_VERSION}.tar distfiles
echo "done"

if [ -f ${STAGEDIR}/.pkg-msg ]; then
	echo ">>> WARNING: The fetch provided additional info."
	cat ${STAGEDIR}/.pkg-msg

	# signal error as well now
	PORTSLIST=
fi

if [ -z "${PORTSLIST}" ]; then
	echo ">>> The distfiles fetch did not finish properly :("
	exit 1
fi
