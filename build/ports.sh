#!/bin/sh

# Copyright (c) 2014-2016 Franco Fichtner <franco@opnsense.org>
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

SELF=ports

. ./common.sh && $(${SCRUB_ARGS})

PORTS_LIST=$(
cat ${CONFIGDIR}/ports.conf | while read PORT_ORIGIN PORT_BROKEN; do
	if [ "$(echo ${PORT_ORIGIN} | colrm 2)" = "#" ]; then
		continue
	fi
	if [ -n "${PORT_BROKEN}" ]; then
		for PORT_QUIRK in $(echo ${PORT_BROKEN} | tr ',' ' '); do
			if [ ${PORT_QUIRK} = ${PRODUCT_ARCH} ]; then
				continue 2
			fi
			if [ ${PORT_QUIRK} = ${PRODUCT_FLAVOUR} ]; then
				continue 2
			fi
		done
	fi

	echo ${PORT_ORIGIN}
done
)

check_packages ${SELF} ${@}

setup_stage ${STAGEDIR}
setup_base ${STAGEDIR}
setup_clone ${STAGEDIR} ${PORTSDIR}
setup_clone ${STAGEDIR} ${SRCDIR}
setup_chroot ${STAGEDIR}
setup_distfiles ${STAGEDIR}

extract_packages ${STAGEDIR}
remove_packages ${STAGEDIR} ${@} ${PRODUCT_PKGNAMES} "os-*" "ospriv-*"
bootstrap_packages ${STAGEDIR}

echo ">>> Building packages..."

MAKE_CONF="${CONFIGDIR}/make.conf"
if [ -f ${MAKE_CONF} ]; then
	cp ${MAKE_CONF} ${STAGEDIR}/etc/make.conf
fi

# block SIGINT to allow for collecting port progress (use with care)
trap : 2

if ! ${ENV_FILTER} chroot ${STAGEDIR} /bin/sh -es << EOF; then SELF=; fi
if ! pkg -N; then
	make -C ${PORTSDIR}/ports-mgmt/pkg install
fi

echo "${PORTS_LIST}" | while read PORT_ORIGIN; do
	if pkg query %n \${PORT_ORIGIN##*/} > /dev/null; then
		continue
	fi

	echo ">>> Building \${PORT_ORIGIN}"
	make -C ${PORTSDIR}/\${PORT_ORIGIN} install \
	    PRODUCT_FLAVOUR=${PRODUCT_FLAVOUR}
done
EOF

# unblock SIGINT
trap - 2

echo ">>> Creating binary packages..."

chroot ${STAGEDIR} /bin/sh -es << EOF && \
    bundle_packages ${STAGEDIR} ${SELF} plugins core
echo "${PORTS_LIST}" | while read PORT_ORIGIN; do
	if pkg query %n \${PORT_ORIGIN##*/} > /dev/null; then
		# lock the package to keep build deps
		pkg lock -qy \${PORT_ORIGIN}
	fi
done
pkg autoremove -y
pkg create -nao ${PACKAGESDIR}/All -f txz
EOF

if [ -z "${SELF}" ]; then
	echo ">>> The ports build did not finish properly :("
	exit 1
fi
