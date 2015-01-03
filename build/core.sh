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

rm -f ${PACKAGESDIR}/${ARCH}/opnsense-*.txz

git_clear ${COREDIR}
git_describe ${COREDIR}

setup_stage ${STAGEDIR}
setup_base ${STAGEDIR}
setup_packages ${STAGEDIR}

# no compiling needed; simply install
make -C ${COREDIR} DESTDIR=${STAGEDIR} install > ${STAGEDIR}/plist

cat >> ${STAGEDIR}/+PRE_DEINSTALL <<EOF
echo "Resetting root shell"
pw usermod -n root -s /bin/csh

echo "Updating /etc/shells"
cp /etc/shells /etc/shells.bak
(grep -v /usr/local/etc/rc.initial /etc/shells.bak) > /etc/shells
rm -f /etc/shells.bak

echo "Unhooking from /etc/rc"
cp /etc/rc /etc/rc.bak
LINES=\$(cat /etc/rc | wc -l)
tail -n \$(expr \${LINES} - 3) /etc/rc.bak > /etc/rc
rm -f /etc/rc.bak

echo "Enabling FreeBSD mirror"
sed -i "" -e "s/^  enabled: no$/  enabled: yes/" /etc/pkg/FreeBSD.conf

echo "Removing OPNsense version"
rm -f /usr/local/etc/version
EOF

cat >> ${STAGEDIR}/+POST_INSTALL <<EOF
echo "Updating /etc/shells"
cp /etc/shells /etc/shells.bak
(grep -v /usr/local/etc/rc.initial /etc/shells.bak; \
    echo /usr/local/etc/rc.initial) > /etc/shells
rm -f /etc/shells.bak

echo "Registering root shell"
pw usermod -n root -s /usr/local/etc/rc.initial

echo "Disabling FreeBSD mirror"
sed -i "" -e "s/^  enabled: yes$/  enabled: no/" /etc/pkg/FreeBSD.conf

echo "Hooking into /etc/rc"
cp /etc/rc /etc/rc.bak
cat > /etc/rc <<EOG
#!/bin/sh
# OPNsense rc(8) hook was automatically installed:
if [ -f /usr/local/etc/rc ]; then /usr/local/etc/rc; exit 0; fi
EOG
cat /etc/rc.bak >> /etc/rc
rm -f /etc/rc.bak

echo "Writing OPNsense version"
echo "${REPO_VERSION}-${REPO_COMMENT}" > /usr/local/etc/version
EOF

cat >> ${STAGEDIR}/+MANIFEST <<EOF
name: opnsense
version: "${REPO_VERSION}"
origin: opnsense/opnsense
comment: "${REPO_COMMENT}"
desc: "OPNsense core package"
maintainer: franco@opnsense.org
www: https://opnsense.org
prefix: /
deps: {
EOF

while read PORT_NAME PORT_CAT PORT_OPT; do
	if [ "${PORT_NAME}" = "#" -o -n "${PORT_OPT}" ]; then
		continue
	fi

	pkg -c ${STAGEDIR} query "  %n: { version: \"%v\", origin: %o }" \
		${PORT_NAME} >> ${STAGEDIR}/+MANIFEST
done < ${TOOLSDIR}/config/current/ports

cat >> ${STAGEDIR}/+MANIFEST <<EOF
}
EOF

echo -n ">>> Creating custom package for ${COREDIR}... "

pkg -c ${STAGEDIR} create -m / -r / -p /plist -o ${PACKAGESDIR}/${ARCH}
mv ${STAGEDIR}${PACKAGESDIR}/${ARCH}/opnsense-*.txz ${PACKAGESDIR}/${ARCH}

echo "done"
