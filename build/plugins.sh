#!/bin/sh

# Copyright (c) 2015-2017 Franco Fichtner <franco@opnsense.org>
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

SELF=plugins

. ./common.sh

PLUGINS_LIST=$(
cat ${CONFIGDIR}/plugins.conf | while read PLUGIN_ORIGIN PLUGIN_IGNORE; do
	if [ "$(echo ${PLUGIN_ORIGIN} | colrm 2)" = "#" ]; then
		continue
	fi
	if [ -n "${PLUGIN_IGNORE}" ]; then
		for PLUGIN_QUIRK in $(echo ${PLUGIN_IGNORE} | tr ',' ' '); do
			if [ ${PLUGIN_QUIRK} = ${PRODUCT_TARGET} -o \
			     ${PLUGIN_QUIRK} = ${PRODUCT_ARCH} -o \
			     ${PLUGIN_QUIRK} = ${PRODUCT_FLAVOUR} ]; then
				continue 2
			fi
		done
	fi

	echo ${PLUGIN_ORIGIN}
done
)

check_packages ${SELF} ${@}

git_branch ${PLUGINSDIR} ${PLUGINSBRANCH} PLUGINSBRANCH

setup_stage ${STAGEDIR}
setup_base ${STAGEDIR}
setup_chroot ${STAGEDIR}

extract_packages ${STAGEDIR}
remove_packages ${STAGEDIR} ${@}
install_packages ${STAGEDIR} pkg git
lock_packages ${STAGEDIR}

for BRANCH in master ${PLUGINSBRANCH}; do
	setup_copy ${STAGEDIR} ${PLUGINSDIR}
	git_reset ${STAGEDIR}${PLUGINSDIR} ${BRANCH}

	for PLUGIN in ${PLUGINS_LIST}; do
		if [ ! -d ${STAGEDIR}${PLUGINSDIR}/${PLUGIN} ]; then
			# not on this branch
			continue
		fi

		PLUGIN_NAME=$(make -C ${STAGEDIR}${PLUGINSDIR}/${PLUGIN} name)
		PLUGIN_DEPS=$(make -C ${STAGEDIR}${PLUGINSDIR}/${PLUGIN} depends)

		if search_packages ${STAGEDIR} ${PLUGIN_NAME}; then
			# already built
			continue
		fi

		install_packages ${STAGEDIR} ${PLUGIN_DEPS}
		custom_packages ${STAGEDIR} ${PLUGINSDIR}/${PLUGIN}
	done
done

bundle_packages ${STAGEDIR} ${SELF}
