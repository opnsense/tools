#!/bin/sh

# Copyright (c) 2014-2022 Franco Fichtner <franco@opnsense.org>
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

SELF=test

. ./common.sh

git_branch ${PLUGINSDIR} ${PLUGINSBRANCH} PLUGINSBRANCH
git_branch ${COREDIR} ${COREBRANCH} COREBRANCH

setup_stage ${STAGEDIR}
setup_base ${STAGEDIR}
setup_clone ${STAGEDIR} ${COREDIR}
setup_clone ${STAGEDIR} ${PLUGINSDIR}
setup_chroot ${STAGEDIR}

extract_packages ${STAGEDIR}
install_packages ${STAGEDIR} ${PRODUCT_CORE} os-debug${PRODUCT_DEVEL}
lock_packages ${STAGEDIR}

echo ">>> Running packages test suite..."
chroot ${STAGEDIR} /bin/sh -es <<EOF
/usr/local/etc/rc.subr.d/recover
pkg check -da
pkg check -sa
EOF

echo ">>> Running ${COREDIR} test suite..."
chroot ${STAGEDIR} /bin/sh -es <<EOF
make -C${COREDIR} ${COREENV} lint
make -C${COREDIR} ${COREENV} style
make -C${COREDIR} ${COREENV} test
EOF

PLUGINSCONF=${CONFIGDIR}/plugins.conf

if [ -f ${PLUGINSCONF}.local ]; then
	PLUGINSCONF="${PLUGINSCONF} ${PLUGINSCONF}.local"
fi

PLUGINSLIST=$(list_packages "${PLUGINSLIST}" ${PLUGINSCONF})

for PLUGIN_ORIGIN in ${PLUGINSLIST}; do
	VARIANT=${PLUGIN_ORIGIN##*@}
	PLUGIN=${PLUGIN_ORIGIN%%@*}

	if [ ! -d ${STAGEDIR}${PLUGINSDIR}/${PLUGIN} ]; then
		echo ">>> Missing ${PLUGIN} origin, skipping test"
		continue
	fi

	PLUGIN_ARGS=${PLUGINSENV}
	if [ ${VARIANT} != ${PLUGIN} ]; then
		PLUGIN_ARGS="${PLUGIN_ARGS} PLUGIN_VARIANT=${VARIANT}"
	fi

	PLUGIN_NAME=$(make -C ${STAGEDIR}${PLUGINSDIR}/${PLUGIN} ${PLUGIN_ARGS} -v PLUGIN_NAME)
	if ! install_packages ${STAGEDIR} os-${PLUGIN_NAME}${PRODUCT_DEVEL}; then
		echo ">>> Missing ${PLUGIN_ORIGIN} package, skipping test"
		continue
	fi

	echo ">>> Running ${PLUGIN_ORIGIN} test suite..."
	chroot ${STAGEDIR} /bin/sh -es <<EOF
make -C${PLUGINSDIR}/${PLUGIN} ${PLUGINSENV} lint
make -C${PLUGINSDIR}/${PLUGIN} ${PLUGINSENV} style
make -C${PLUGINSDIR}/${PLUGIN} ${PLUGINSENV} test
EOF
done
