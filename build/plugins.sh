#!/bin/sh

# Copyright (c) 2015-2019 Franco Fichtner <franco@opnsense.org>
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

if [ -z "${PLUGINS_LIST}" ]; then
	PLUGINS_LIST=$(
cat ${CONFIGDIR}/plugins.conf | while read PLUGIN_ORIGIN PLUGIN_IGNORE; do
	if [ "$(echo ${PLUGIN_ORIGIN} | colrm 2)" = "#" ]; then
		continue
	fi
	if [ -n "${PLUGIN_IGNORE}" ]; then
		QUICK=
		for PLUGIN_QUIRK in $(echo ${PLUGIN_IGNORE} | tr ',' ' '); do
			if [ ${PLUGIN_QUIRK} = ${PRODUCT_TARGET} -o \
			     ${PLUGIN_QUIRK} = ${PRODUCT_ARCH} -o \
			     ${PLUGIN_QUIRK} = ${PRODUCT_FLAVOUR} ]; then
				continue 2
			fi
			if [ ${PLUGIN_QUIRK} = "quick" ]; then
				QUICK=1
			fi
		done
		if [ -n "${PRODUCT_QUICK}" -a -z "${QUICK}" ]; then
			# speed up build by skipping all annotations,
			# our core should work without all of them.
			continue
		fi
	fi
	echo ${PLUGIN_ORIGIN}
done
)
else
	PLUGINS_LIST=$(
for PLUGIN_ORIGIN in ${PLUGINS_LIST}; do
	echo ${PLUGIN_ORIGIN}
done
)
fi

check_packages ${SELF} ${@}

git_branch ${PLUGINSDIR} ${PLUGINSBRANCH} PLUGINSBRANCH

setup_stage ${STAGEDIR}
setup_base ${STAGEDIR}
setup_chroot ${STAGEDIR}

extract_packages ${STAGEDIR}
remove_packages ${STAGEDIR} ${@}
install_packages ${STAGEDIR} pkg git
lock_packages ${STAGEDIR}

for BRANCH in ${DEVELBRANCH} ${PLUGINSBRANCH}; do
	setup_copy ${STAGEDIR} ${PLUGINSDIR}
	git_reset ${STAGEDIR}${PLUGINSDIR} ${BRANCH}

	PLUGIN_ARGS="PLUGIN_ARCH=${PRODUCT_ARCH} ${PLUGINSENV}"

	for PLUGIN in ${PLUGINS_LIST}; do
		PLUGIN_NAME=$(make -C ${STAGEDIR}${PLUGINSDIR}/${PLUGIN} ${PLUGIN_ARGS} name)
		PLUGIN_DEPS=$(make -C ${STAGEDIR}${PLUGINSDIR}/${PLUGIN} ${PLUGIN_ARGS} depends)

		if search_packages ${STAGEDIR} ${PLUGIN_NAME}; then
			# already built
			continue
		fi

		install_packages ${STAGEDIR} ${PLUGIN_DEPS}
		custom_packages ${STAGEDIR} ${PLUGINSDIR}/${PLUGIN} "${PLUGIN_ARGS}"
	done
done

bundle_packages ${STAGEDIR} ${SELF}
