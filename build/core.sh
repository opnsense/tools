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

PORT_LIST="${TOOLSDIR}/config/current/ports"

rm -f ${PACKAGESDIR}/opnsense-*.txz
mkdir -p ${PACKAGESDIR}
setup_stage ${STAGEDIR}

(cd ${STAGEDIR}; find * -type f ! -name plist) > ${STAGEDIR}/plist

update_etc_shell()
{
	cat >> ${STAGEDIR}/+POST_INSTALL <<EOF
echo "Updating /etc/shells"
cp /etc/shells /etc/shells.bak
(grep -v ${1} /etc/shells.bak; echo ${1}) >/etc/shells
rm -f /etc/shells.bak
EOF

	cat >> ${STAGEDIR}/+PRE_DEINSTALL <<EOF
echo "Updating /etc/shells"
cp /etc/shells /etc/shells.bak
(grep -v ${1} /etc/shells.bak) >/etc/shells
rm -f /etc/shells.bak
EOF
}

# !!! BEGIN ORDERING IS IMPORTANT !!!

cat >> ${STAGEDIR}/+PRE_DEINSTALL <<EOF
echo "Resetting root shell"
pw usermod -n root -s /bin/csh
EOF

update_etc_shell /usr/local/etc/rc.initial

cat >> ${STAGEDIR}/+POST_INSTALL <<EOF
echo "Registering root shell"
pw usermod -n root -s /usr/local/etc/rc.initial
EOF

# !!! END ORDERING IS IMPORTANT !!!

cat > ${STAGEDIR}/+MANIFEST <<EOF
name: opnsense
version: current
origin: opnsense/opnsense
comment: "XXX needs versioning"
desc: "OPNsense core package"
maintainer: franco@opnsense.org
www: https://opnsense.org
prefix: /
EOF

echo "deps: {" >> ${STAGEDIR}/+MANIFEST

while read PORT_NAME PORT_CAT PORT_OPT; do
	if [ "${PORT_NAME}" = "#" -o -n "${PORT_OPT}" ]; then
		continue
	fi

	pkg query "  %n: { version: \"%v\", origin: %o }" \
		${PORT_NAME} >> ${STAGEDIR}/+MANIFEST
done < ${PORT_LIST}

echo "}" >> ${STAGEDIR}/+MANIFEST

echo -n ">>> Creating custom package for ${COREDIR}... "

pkg create -m ${STAGEDIR} -r ${STAGEDIR} -p ${STAGEDIR}/plist -o ${PACKAGESDIR}

echo "done"
