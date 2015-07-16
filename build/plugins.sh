#!/bin/sh

# Copyright (c) 2015 Franco Fichtner <franco@opnsense.org>
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

PLUGINS=$(make -C ${PLUGINSDIR} list)
PLUGIN_NAMES=

for PLUGIN in ${PLUGINS}; do
	PLUGIN_NAMES="${PLUGIN_NAMES} $(make -C ${PLUGINSDIR}/${PLUGIN} name)"
done

setup_stage ${STAGEDIR}
setup_base ${STAGEDIR}
setup_clone ${STAGEDIR} ${PLUGINSDIR}
extract_packages ${STAGEDIR} ${PLUGIN_NAMES}
install_packages ${STAGEDIR}

for PLUGIN in ${PLUGINS}; do
	chroot ${STAGEDIR} /bin/sh -es << EOF

make -C ${PLUGINSDIR}/${PLUGIN} DESTDIR=${STAGEDIR} install
make -C ${PLUGINSDIR}/${PLUGIN} DESTDIR=${STAGEDIR} scripts

make -C ${PLUGINSDIR}/${PLUGIN} DESTDIR=${STAGEDIR} manifest > ${STAGEDIR}/+MANIFEST
make -C ${PLUGINSDIR}/${PLUGIN} DESTDIR=${STAGEDIR} plist > ${STAGEDIR}/plist
EOF
	create_packages ${STAGEDIR} $(make -C ${PLUGINSDIR}/${PLUGIN} name)
done

bundle_packages ${STAGEDIR}
