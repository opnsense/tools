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

PORT_LIST=$(cat ${PRODUCT_CONFIG}/ports.conf)

git_clear ${PORTSDIR}
git_clear ${SRCDIR}

setup_stage ${STAGEDIR}
setup_base ${STAGEDIR}
setup_clone ${STAGEDIR} ${PORTSDIR}
setup_clone ${STAGEDIR} ${SRCDIR}
setup_chroot ${STAGEDIR}

# bootstrap the stage with the avilable set (minus opnsense and args)
extract_packages ${STAGEDIR} opnsense ${@}
install_packages ${STAGEDIR}
clean_packages ${STAGEDIR}

echo ">>> Building packages..."

MAKE_CONF="${PRODUCT_CONFIG}/make.conf"
if [ -f ${MAKE_CONF} ]; then
	cp ${MAKE_CONF} ${STAGEDIR}/etc/make.conf
fi

# block SIGINT to allow for collecting port progress (use with care)
trap : 2

if ! chroot ${STAGEDIR} /bin/sh -es << EOF; then PORT_ABORT=1; fi
# overwrites the ports tree variable, behaviour is unwanted...
unset STAGEDIR
# ...and this unbreaks the nmap build
unset TARGET_ARCH

if pkg -N; then
	# no need to rebuild
else
	make -C ${PORTSDIR}/ports-mgmt/pkg rmconfig-recursive
	make -C ${PORTSDIR}/ports-mgmt/pkg clean all install
fi

echo "${PORT_LIST}" | { while read PORT_NAME PORT_CAT PORT_OPT; do
	if [ "\$(echo \${PORT_NAME} | colrm 2)" = "#" -o "\${PORT_OPT}" = "sync" ]; then
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
done }
EOF

# unblock SIGINT
trap - 2

echo ">>> Creating binary packages..."

chroot ${STAGEDIR} /bin/sh -es << EOF && bundle_packages ${STAGEDIR}
pkg_resolve_deps()
{
	local PORTS DEPS PORT DEP

	DEPS="\$(pkg info -qd \${1})"
	PORTS="\${1} \${DEPS}"

	for DEP in \${DEPS}; do
		# recurse into hell and back
		pkg_resolve_deps \${DEP}
	done

	for PORT in \${PORTS}; do
		pkg create -no ${PACKAGESDIR}/All -f txz \${PORT}
	done
}

mkdir -p ${PACKAGESDIR}/All

# sometimes stuck in an endless loop
trap 'exit 0' 2

pkg_resolve_deps pkg

echo "${PORT_LIST}" | { while read PORT_NAME PORT_CAT PORT_OPT; do
	if [ "\$(echo \${PORT_NAME} | colrm 2)" = "#" -o "\${PORT_OPT}" = "sync" ]; then
		continue
	fi

	pkg_resolve_deps "\$(pkg info -E \${PORT_NAME})"
done }
EOF

if [ -n "${PORT_ABORT}" ]; then
	echo ">>> The ports build did not finish properly :("
	exit 1
fi
