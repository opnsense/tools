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

. ./common.sh && $(${SCRUB_ARGS})

# rewrite the disk label, because we're install media
LABEL="${LABEL}_Install"

setup_stage ${STAGEDIR}
setup_base ${STAGEDIR}
setup_kernel ${STAGEDIR}
setup_packages ${STAGEDIR} opnsense
setup_mtree ${STAGEDIR}

echo -n ">>> Building ISO image... "

# must be upper case:
LABEL=$(echo ${LABEL} | tr '[:lower:]' '[:upper:]')

cat > ${STAGEDIR}/etc/fstab << EOF
# Device	Mountpoint	FStype	Options	Dump	Pass #
/dev/iso9660/${LABEL}	/	cd9660	ro	0	0
tmpfs		/tmp		tmpfs	rw,mode=01777	0	0
EOF

makefs -t cd9660 -o bootimage="i386;${STAGEDIR}/boot/cdboot" \
    -o no-emul-boot -o label=${LABEL} -o rockridge ${CDROM} ${STAGEDIR}

echo "done:"

ls -lah ${IMAGESDIR}/*
