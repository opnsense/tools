#!/bin/sh

# Copyright (c) 2015-2017 Franco Fichtner <franco@opnsense.org>
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

if [ -z "${PORTS_LIST}" ]; then
	PORTS_LIST=$(
cat ${CONFIGDIR}/skim.conf ${CONFIGDIR}/ports.conf | \
    while read PORT_ORIGIN PORT_IGNORE; do
	eval PORT_ORIGIN=${PORT_ORIGIN}
	if [ "$(echo ${PORT_ORIGIN} | colrm 2)" = "#" ]; then
		continue
	fi
	if [ -n "${PORT_IGNORE}" ]; then
		for PORT_QUIRK in $(echo ${PORT_IGNORE} | tr ',' ' '); do
			if [ ${PORT_QUIRK} = ${PRODUCT_TARGET} -o \
			     ${PORT_QUIRK} = ${PRODUCT_ARCH} -o ]; then
				continue 2
			fi
		done
	fi
	echo ${PORT_ORIGIN}
done
)
else
	PORTS_LIST=$(
for PORT_ORIGIN in ${PORTS_LIST}; do
	echo ${PORT_ORIGIN}
done
)
fi

git_branch ${SRCDIR} ${SRCBRANCH} SRCBRANCH
git_branch ${PORTSDIR} ${PORTSBRANCH} PORTSBRANCH

setup_stage ${STAGEDIR}
setup_base ${STAGEDIR}
setup_clone ${STAGEDIR} ${PORTSDIR}
setup_clone ${STAGEDIR} ${SRCDIR}
setup_chroot ${STAGEDIR}
setup_distfiles ${STAGEDIR}

git_describe ${PORTSDIR}

echo ">>> Fetching distfiles..."

MAKE_CONF="${CONFIGDIR}/make.conf"
if [ -f ${MAKE_CONF} ]; then
	cp ${MAKE_CONF} ${STAGEDIR}/etc/make.conf
fi

echo "CLEAN_FETCH_ENV=yes" >> ${STAGEDIR}/etc/make.conf

# block SIGINT to allow for collecting port progress (use with care)
trap : 2

if ! ${ENV_FILTER} chroot ${STAGEDIR} /bin/sh -es << EOF; then PORTS_LIST=; fi
echo "${PORTS_LIST}" | while read PORT_ORIGIN; do
	echo ">>> Fetching \${PORT_ORIGIN}..."
	make -C ${PORTSDIR}/\${PORT_ORIGIN} fetch-recursive \
	    PRODUCT_FLAVOUR=${PRODUCT_FLAVOUR} \
	    PRODUCT_PHP=${PRODUCT_PHP} \
	    UNAME_r=\$(freebsd-version)
done
EOF

# unblock SIGINT
trap - 2

sh ./clean.sh ${SELF}

echo -n ">>> Creating distfiles set... "
tar -C ${STAGEDIR}${PORTSDIR} -cf \
    ${SETSDIR}/distfiles-${REPO_VERSION}.tar distfiles
echo "done"

if [ -z "${PORTS_LIST}" ]; then
	echo ">>> The distfiles fetch did not finish properly :("
	exit 1
fi
