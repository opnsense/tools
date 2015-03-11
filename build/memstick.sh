#!/bin/sh

# Copyright (c) 2010-2011 Scott Ullrich <sullrich@gmail.com>
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

mkdir -p ${IMAGESDIR}

setup_stage ${STAGEDIR}
setup_base ${STAGEDIR}
setup_kernel ${STAGEDIR}
setup_packages ${STAGEDIR} opnsense
setup_mtree ${STAGEDIR}
setup_platform ${STAGEDIR}

echo ">>> Building memstick image(s)..."

cat > ${STAGEDIR}/etc/fstab << EOF
# Device	Mountpoint	FStype	Options	Dump	Pass#
/dev/ufs/${LABEL}	/	ufs	ro,noatime	1	1
tmpfs		/tmp		tmpfs	rw,mode=01777	0	0
EOF

makefs -t ffs -B little -o label=${LABEL} ${VGAIMG} ${STAGEDIR}

# Activate serial console boot
echo "-S115200 -D" > ${STAGEDIR}/boot.config

# Activate serial console in config.xml
DEFAULTCONF=${STAGEDIR}/usr/local/etc/config.xml
# If it wasn't there before, enable serial in the config:
if ! grep -q -F "<enableserial/>" ${DEFAULTCONF}; then
	sed -i "" -e "s:</system>:<enableserial/></system>:" ${DEFAULTCONF}
fi

# Activate serial console+video console
cat > ${STAGEDIR}/boot/loader.conf <<EOF
boot_multicons="YES"
boot_serial="YES"
console="comconsole,vidconsole"
comconsole_speed="115200"
EOF

# Activate serial console TTY
sed -i "" -Ee 's:^ttyu0:ttyu0	"/usr/libexec/getty std.9600"	cons25	on  secure:' ${STAGEDIR}/etc/ttys

makefs -t ffs -B little -o label=${LABEL} ${SERIALIMG} ${STAGEDIR}

setup_bootcode()
{
	local dev

	dev=$(mdconfig -a -t vnode -f "${1}")
	gpart create -s BSD "${dev}"
	gpart bootcode -b "${STAGEDIR}"/boot/boot "${dev}"
	gpart add -t freebsd-ufs "${dev}"
	mdconfig -d -u "${dev}"
}

setup_bootcode ${VGAIMG}
setup_bootcode ${SERIALIMG}

echo "done:"

ls -lah ${IMAGESDIR}/*
