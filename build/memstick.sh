#!/bin/sh

# Copyright (C) 2010-2011 Scott Ullrich <sullrich@gmail.com>
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

mkdir -p ${IMAGESDIR}

setup_stage ${STAGEDIR}
setup_base ${STAGEDIR}
setup_kernel ${STAGEDIR}
setup_packages ${STAGEDIR}
setup_mtree ${STAGEDIR}
setup_platform ${STAGEDIR}

echo ">>> Building memstick image(s)..."

LABEL="OPNsense"

WORKDIR=/tmp/memstick.$$

rm -rf ${WORKDIR}
mkdir -p ${WORKDIR}

mkdir ${WORKDIR}/etc
echo "/dev/ufs/${LABEL} / ufs ro 0 0" > ${WORKDIR}/etc/fstab

makefs -t ffs -B little -o label=${LABEL} ${MEMSTICKPATH} ${STAGEDIR} ${WORKDIR}

# Now create serial memstick by reusing the above
# modifications in WORKDIR to avoid a mount call,
# which doesn't work in jails...

# Activate serial console boot
echo "-D" > ${WORKDIR}/boot.config

# Activate serial console in config.xml
DEFAULTCONF=${STAGEDIR}/usr/local/etc/config.xml
# If it wasn't there before, enable serial in the config:
if ! grep -q -F "<enableserial/>" ${DEFAULTCONF}; then
	sed -i "" -e "s:</system>:<enableserial/></system>:" ${DEFAULTCONF}
fi

# XXX setup of initial config should be done at boot time
cp ${DEFAULTCONF} ${STAGEDIR}/cf/conf/config.xml

# Activate serial console+video console
mkdir -p ${WORKDIR}/boot
cat > ${WORKDIR}/boot/loader.conf <<EOF
boot_multicons="YES"
boot_serial="YES"
console="comconsole,vidconsole"
EOF

# Activate serial console TTY
mv ${STAGEDIR}/etc/ttys ${WORKDIR}/etc/ttys
sed -i "" -Ee 's:^ttyu0:ttyu0	"/usr/libexec/getty std.9600"	cons25	on  secure:' ${WORKDIR}/etc/ttys

makefs -t ffs -B little -o label=${LABEL} ${MEMSTICKSERIALPATH} ${STAGEDIR} ${WORKDIR}

rm -r "${WORKDIR}"

setup_bootcode()
{
	local dev

	dev=$(mdconfig -a -t vnode -f "${1}")
	gpart create -s BSD "${dev}"
	gpart bootcode -b "${STAGEDIR}"/boot/boot "${dev}"
	gpart add -t freebsd-ufs "${dev}"
	mdconfig -d -u "${dev}"
}

setup_bootcode ${MEMSTICKPATH}
setup_bootcode ${MEMSTICKSERIALPATH}

echo "done:"

ls -lah ${IMAGESDIR}/*
