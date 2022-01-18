#!/bin/sh

# Copyright (c) 2022 Franco Fichtner <franco@opnsense.org>
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

SELF=audit

. ./common.sh

PORTSLIST=$(list_config PORTS ${CONFIGDIR}/aux.conf ${CONFIGDIR}/ports.conf)

setup_stage ${STAGEDIR}
setup_base ${STAGEDIR}
setup_chroot ${STAGEDIR}
extract_packages ${STAGEDIR}
install_packages ${STAGEDIR} pkg
lock_packages ${STAGEDIR}

for PKG in $(cd ${STAGEDIR}; find .${PACKAGESDIR}/All -type f); do
	PKGORIGIN=$(pkg -c ${STAGEDIR} info -F ${PKG} | \
	    grep ^Origin | awk '{ print $3; }')

	for PORT in ${PORTSLIST}; do
		PORT=${PORT%%@*}
		if [ "${PORT}" = "${PKGORIGIN}" ]; then
			${ENV_FILTER} chroot ${STAGEDIR} /bin/sh -s << EOF
echo -n "Auditing ${PORT}... "
STATUS=ok
pkg add -f ${PKG} 2> /dev/null > /dev/null
AUDIT=\$(pkg audit -F | grep is.vulnerable | tr -d :)
if [ -n "\${AUDIT}" ]; then
	echo "\${AUDIT}" >> /report
	STATUS=vulnerable
fi
pkg remove -qya > /dev/null
echo \${STATUS}
EOF
		fi
	done
done

if [ -f ${STAGEDIR}/report ]; then
	echo ">>> The following vulnerable packages exist:"
	sort -u ${STAGEDIR}/report
	exit 1
else
	echo ">>> No vulnerable packages have been found."
fi
