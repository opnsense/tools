#!/bin/sh

# Copyright (c) 2014-2017 Franco Fichtner <franco@opnsense.org>
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

. ./common.sh

PORTS_LIST=$(
cat ${CONFIGDIR}/ports.conf | while read PORT_ORIGIN PORT_IGNORE; do
	if [ "$(echo ${PORT_ORIGIN} | colrm 2)" = "#" ]; then
		continue
	fi
	if [ -n "${PORT_IGNORE}" ]; then
		for PORT_QUIRK in $(echo ${PORT_IGNORE} | tr ',' ' '); do
			if [ ${PORT_QUIRK} = ${PRODUCT_TARGET} -o \
			     ${PORT_QUIRK} = ${PRODUCT_ARCH} -o \
			     ${PORT_QUIRK} = ${PRODUCT_FLAVOUR} ]; then
				continue 2
			fi
		done
	fi

	echo ${PORT_ORIGIN}
done
)

check_packages ${SELF} ${@}

git_branch ${SRCDIR} ${SRCBRANCH} SRCBRANCH
git_branch ${PORTSDIR} ${PORTSBRANCH} PORTSBRANCH

setup_stage ${STAGEDIR}
setup_base ${STAGEDIR}
setup_clone ${STAGEDIR} ${PORTSDIR}
setup_clone ${STAGEDIR} ${SRCDIR}
setup_chroot ${STAGEDIR}
setup_distfiles ${STAGEDIR}

extract_packages ${STAGEDIR}
remove_packages ${STAGEDIR} ${@} ${PRODUCT_PKGNAMES} "os-*"

for PKG in $(cd ${STAGEDIR}; find .${PACKAGESDIR}/All -type f); do
	# all packages that install have their dependencies fulfilled
	if pkg -c ${STAGEDIR} add ${PKG}; then
		continue
	fi

	# some packages clash in files with others, check for conflicts
	PKGORIGIN=$(pkg -c ${STAGEDIR} info -F ${PKG} | grep ^Origin | awk '{ print $3; }')
	PKGGLOBS=
	for CONFLICTS in CONFLICTS CONFLICTS_INSTALL; do
		PKGGLOBS="${PKGGLOBS} $(make -C ${PORTSDIR}/${PKGORIGIN} -V ${CONFLICTS})"
	done
	for PKGGLOB in ${PKGGLOBS}; do
		pkg -c ${STAGEDIR} remove -gy "${PKGGLOB}" || true
	done

	# if the conflicts are resolved this works now, but remove
	# the package again as it may clash again later...
	if pkg -c ${STAGEDIR} add ${PKG}; then
		pkg -c ${STAGEDIR} remove -y ${PKGORIGIN}
		continue
	fi

	# if nothing worked, we are missing a dependency and force a rebuild
	rm -f ${STAGEDIR}/${PKG}
done

MAKE_CONF="${CONFIGDIR}/make.conf"
if [ -f ${MAKE_CONF} ]; then
	cp ${MAKE_CONF} ${STAGEDIR}/etc/make.conf
fi

# block SIGINT to allow for collecting port progress (use with care)
trap : 2

if ! ${ENV_FILTER} chroot ${STAGEDIR} /bin/sh -es << EOF; then SELF=; fi
PKG_ORIGIN="ports-mgmt/pkg"

if ! pkg -N; then
	make -C ${PORTSDIR}/\${PKG_ORIGIN} install \
	    UNAME_r=\$(freebsd-version)
fi

pkg set -yaA1
pkg set -yA0 \${PKG_ORIGIN}
pkg autoremove -y

pkg create -nao ${PACKAGESDIR}/All -f txz

echo "${PORTS_LIST}" | while read PORT_ORIGIN; do
	# check whether the package has already been built
	PKGFILE=\$(make -C ${PORTSDIR}/\${PORT_ORIGIN} -V PKGFILE \
	    PRODUCT_FLAVOUR=${PRODUCT_FLAVOUR} PACKAGES=${PACKAGESDIR} \
	    UNAME_r=\$(freebsd-version))
	if [ -f \${PKGFILE} ]; then
		continue
	fi

	# check whether the package is available as an older version
	PKGNAME=\$(basename \${PKGFILE})
	PKGNAME=\${PKGNAME%%-[0-9]*}.txz
	PKGFILE=${PACKAGESDIR}/Latest/\${PKGNAME}
	if [ -L \${PKGFILE} ]; then
		PKGFILE=\$(readlink -f \${PKGFILE})
		echo ">>> A different version of \${PORT_ORIGIN} exists!"
		echo ">>> The build may fail or have integrity issues!"
		continue
	fi

	make -C ${PORTSDIR}/\${PORT_ORIGIN} install \
	    PRODUCT_FLAVOUR=${PRODUCT_FLAVOUR} PACKAGES=${PACKAGESDIR} \
	    USE_PACKAGE_DEPENDS=yes UNAME_r=\$(freebsd-version)

	echo "${PORTS_LIST}" | while read PORT_DEPENDS; do
		PORT_DEPNAME=\$(pkg query -e "%o == \${PORT_DEPENDS}" %n)
		if [ -n "\${PORT_DEPNAME}" ]; then
			pkg set -yA0 \${PORT_DEPNAME}
		fi
	done

	pkg autoremove -y
	pkg create -nao ${PACKAGESDIR}/All -f txz

	make -C ${PORTSDIR}/\${PORT_ORIGIN} clean \
	    PRODUCT_FLAVOUR=${PRODUCT_FLAVOUR} \
	    UNAME_r=\$(freebsd-version)

	pkg set -yaA1
	pkg set -yA0 \${PKG_ORIGIN}
	pkg autoremove -y
done
EOF

# unblock SIGINT
trap - 2

bundle_packages ${STAGEDIR} "${SELF}" ports plugins core

if [ "${SELF}" != "ports" ]; then
	echo ">>> The ports build did not finish properly :("
	exit 1
fi
