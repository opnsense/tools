#!/bin/sh

# Copyright (c) 2014-2021 Franco Fichtner <franco@opnsense.org>
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

eval ${PORTSENV}

ARGS=${*}
DEPS=

for OPT in BATCH DEPEND PRUNE; do
	VAL=$(eval echo \$${OPT});
	case ${VAL} in
	yes|no)
		;;
	'')
		eval ${OPT}=yes
		;;
	*)
		echo ">>> Syntax error ${OPT}=${VAL}: use 'yes' or 'no'"
		exit 1
		;;
	esac
done

if check_packages ${SELF} ${ARGS}; then
	echo ">>> Step ${SELF} is up to date"
	exit 0
fi

PORTCONFIGS="${CONFIGDIR}/ports.conf"

# inject auxiliary ports only if not already removed
if ! check_packages packages; then
	PORTCONFIGS="${CONFIGDIR}/aux.conf ${PORTCONFIGS}"
fi

PORTSLIST=$(list_ports ${PORTCONFIGS})

git_branch ${SRCDIR} ${SRCBRANCH} SRCBRANCH
git_branch ${PORTSDIR} ${PORTSBRANCH} PORTSBRANCH

setup_stage ${STAGEDIR}
setup_base ${STAGEDIR}
setup_clone ${STAGEDIR} ${PORTSDIR}
setup_clone ${STAGEDIR} ${SRCDIR}
setup_chroot ${STAGEDIR}
setup_distfiles ${STAGEDIR}

if extract_packages ${STAGEDIR}; then
	if [ ${DEPEND} = "yes" ]; then
		ARGS="${ARGS} ${PRODUCT_CORES} ${PRODUCT_PLUGINS}"
		DEPS="plugins core"
	fi
	remove_packages ${STAGEDIR} ${ARGS}
	if [ ${PRUNE} = "yes" ]; then
		prune_packages ${STAGEDIR}
	fi
fi

sh ./make.conf.sh > ${STAGEDIR}/etc/make.conf

if [ ${BATCH} = "no" ]; then
	sed -i '' -e 's/^#DEVELOPER=/DEVELOPER=/' ${STAGEDIR}/etc/make.conf
fi

cat > ${STAGEDIR}/bin/echotime <<EOF
#!/bin/sh
echo "[\$(date '+%Y%m%d%H%M%S')]" \${*}
EOF

chmod 755 ${STAGEDIR}/bin/echotime

echo "ECHO_MSG=echotime" >> ${STAGEDIR}/etc/make.conf

# block SIGINT to allow for collecting port progress (use with care)
trap : 2

${ENV_FILTER} chroot ${STAGEDIR} /bin/sh -s << EOF || true
# create a caching mirror for all temporary package dependencies
mkdir -p ${PACKAGESDIR}-cache
cp -R ${PACKAGESDIR}/All ${PACKAGESDIR}-cache/All

echo "${PORTSLIST}
clean.up.post.build" | while read PORT_ORIGIN; do
	FLAVOR=\${PORT_ORIGIN##*@}
	PORT=\${PORT_ORIGIN%%@*}
	MAKE_ARGS="
PACKAGES=${PACKAGESDIR}-cache
PRODUCT_ABI=${PRODUCT_ABI}
PRODUCT_ARCH=${PRODUCT_ARCH}
PRODUCT_FLAVOUR=${PRODUCT_FLAVOUR}
UNAME_r=\$(freebsd-version)
"

	# if pkg is bootstrapped then unstrap it
	if [ -f /usr/local/sbin/pkg ]; then
		pkg set -yaA1
		pkg autoremove -y
	fi

	if [ \${PORT} = "clean.up.post.build" ]; then
		continue
	fi

	if [ \${FLAVOR} != \${PORT} ]; then
		MAKE_ARGS="\${MAKE_ARGS} FLAVOR=\${FLAVOR}"
	fi

	# check whether the package has already been built
	PKGFILE=\$(make -C ${PORTSDIR}/\${PORT} -v PKGFILE \${MAKE_ARGS})
	if [ -f \${PKGFILE%%.pkg}.txz ]; then
		continue
	fi

	# check whether the package is available
	# under a different version number
	PKGNAME=\$(basename \${PKGFILE})
	PKGNAME=\${PKGNAME%%-[0-9]*}.txz
	PKGLINK=${PACKAGESDIR}/Latest/\${PKGNAME}
	if [ -L \${PKGLINK} ]; then
		PKGFILE=\$(readlink -f \${PKGLINK} || true)
		if [ -f \${PKGFILE} ]; then
			PKGVERS=\$(make -C ${PORTSDIR}/\${PORT} -v PKGVERSION \${MAKE_ARGS})
			echo ">>> Skipped version \${PKGVERS} for \${PORT_ORIGIN}" >> /.pkg-warn
			continue
		fi
	fi

	PKGVERS=\$(make -C ${PORTSDIR}/\${PORT} -v PKGVERSION \${MAKE_ARGS})

	if ! make -C ${PORTSDIR}/\${PORT} install \
	    USE_PACKAGE_DEPENDS=yes \${MAKE_ARGS}; then
		echo ">>> Aborted version \${PKGVERS} for \${PORT_ORIGIN}" >> /.pkg-err

		CONTINUE=

		if [ ${BATCH} = "no" ]; then
			echo ">>> Interactive shell for \${PORT} (use \"exit 1\" to abort)"
			(cd ${PORTSDIR}/\${PORT}; sh < /dev/tty) || exit 1
			CONTINUE=1
		fi

		if [ -n "${PRODUCT_REBUILD}" -a -z "\${CONTINUE}" ]; then
			exit 1
		fi

		make -C ${PORTSDIR}/\${PORT} clean \${MAKE_ARGS}
		continue
	elif ! make -C ${PORTSDIR}/\${PORT} check-plist \${MAKE_ARGS}; then
		echo ">>> Package list inconsistency for \${PORT_ORIGIN}" >> /.pkg-warn
	fi

	if [ -n "${PRODUCT_REBUILD}" ]; then
		echo ">>> Rebuilt version \${PKGVERS} for \${PORT_ORIGIN}" >> /.pkg-warn
	fi

	for PKGNAME in \$(pkg query %n); do
		pkg create -no ${PACKAGESDIR}-cache/All \${PKGNAME}
	done

	echo "${PORTSLIST}" | while read PORT_DEPENDS; do
		PORT_DEPNAME=\$(pkg query -e "%o == \${PORT_DEPENDS%%@*}" %n)
		if [ -n "\${PORT_DEPNAME}" ]; then
			echo ">>> Locking package dependency: \${PORT_DEPNAME}"
			pkg set -yA0 \${PORT_DEPNAME}
		fi
	done

	pkg autoremove -y

	for PKGNAME in \$(pkg query %n); do
		OLD=\$(find ${PACKAGESDIR}/All -name "\${PKGNAME}-[0-9]*.txz")
		if [ -n "\${OLD}" ]; then
			# already found
			continue
		fi
		NEW=\$(find ${PACKAGESDIR}-cache/All -name "\${PKGNAME}-[0-9]*.txz")
		echo ">>> Saving runtime package: \${PKGNAME}"
		cp \${NEW} ${PACKAGESDIR}/All
	done

	make -C ${PORTSDIR}/\${PORT} clean \${MAKE_ARGS}
done
EOF

# unblock SIGINT
trap - 2

bundle_packages ${STAGEDIR} ${SELF} ${DEPS}
