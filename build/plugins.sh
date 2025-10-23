#!/bin/sh

# Copyright (c) 2015-2025 Franco Fichtner <franco@opnsense.org>
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

if check_packages ${SELF} ${@}; then
	echo ">>> Step ${SELF} is up to date"
	exit 0
fi

PLUGINSCONF=${CONFIGDIR}/plugins.conf

if [ -f ${PLUGINSCONF}.local ]; then
	PLUGINSCONF="${PLUGINSCONF} ${PLUGINSCONF}.local"
fi

PLUGINSLIST=$(list_packages "${PLUGINSLIST}" ${PLUGINSCONF})
_PLUGIN_ARGS="PLUGIN_ARCH=${PRODUCT_ARCH} ${PLUGINSENV}"

git_branch ${PLUGINSDIR} ${PLUGINSBRANCH} PLUGINSBRANCH

setup_stage ${STAGEDIR}
setup_base ${STAGEDIR}
setup_chroot ${STAGEDIR}

extract_packages ${STAGEDIR}
remove_packages ${STAGEDIR} ${@}
install_packages ${STAGEDIR} pkg git
lock_packages ${STAGEDIR}

for BRANCH in ${EXTRABRANCH} ${PLUGINSBRANCH}; do
	setup_copy ${STAGEDIR} ${PLUGINSDIR}
	git_reset ${STAGEDIR}${PLUGINSDIR} ${BRANCH}

	PREFIX=${PRODUCT_PLUGINS%"*"}
	PLUGIN_LIST=
	PLUGIN_DEFER=

	for PLUGIN_ORIGIN in ${PLUGINSLIST}; do
		PLUGIN=${PLUGIN_ORIGIN%%@*}

		if [ ! -d ${STAGEDIR}${PLUGINSDIR}/${PLUGIN} ]; then
			continue
		fi

		PLUGIN_DEPS=$(make -C ${STAGEDIR}${PLUGINSDIR}/${PLUGIN} ${_PLUGIN_ARGS} -v PLUGIN_DEPENDS)
		for PLUGIN_DEP in ${PLUGIN_DEPS}; do
			if [ -z "${PLUGIN_DEP%%"${PREFIX}"*}" ]; then
				PLUGIN_DEFER="${PLUGIN_DEFER} ${PLUGIN_ORIGIN}"
				continue 2
			fi
		done

		PLUGIN_LIST="${PLUGIN_LIST} ${PLUGIN_ORIGIN}"
	done

	for PLUGIN_ORIGIN in ${PLUGIN_LIST} ${PLUGIN_DEFER}; do
		VARIANT=${PLUGIN_ORIGIN##*@}
		PLUGIN=${PLUGIN_ORIGIN%%@*}

		if [ ${BRANCH} != ${PLUGINSBRANCH} -a \
		    ! -d ${STAGEDIR}${PLUGINSDIR}/${PLUGIN} ]; then
			# require plugins in the main branch but
			# not in extra branches to allow for drift
			continue
		fi

		PLUGIN_ARGS=${_PLUGIN_ARGS}
		if [ ${VARIANT} != ${PLUGIN} ]; then
			PLUGIN_ARGS="${PLUGIN_ARGS} PLUGIN_VARIANT=${VARIANT}"
		fi

		PLUGIN_GONE=$(make -C ${STAGEDIR}${PLUGINSDIR}/${PLUGIN} ${PLUGIN_ARGS} -v PLUGIN_OBSOLETE)
		if [ -n "${PLUGIN_GONE}" ]; then
			# if the plugin has the obsolete flag
			# set we no longer include its package
			continue
		fi

		PLUGIN_NAME=$(make -C ${STAGEDIR}${PLUGINSDIR}/${PLUGIN} ${PLUGIN_ARGS} -v PLUGIN_PKGNAME)
		PLUGIN_DEPS=$(make -C ${STAGEDIR}${PLUGINSDIR}/${PLUGIN} ${PLUGIN_ARGS} -v PLUGIN_DEPENDS)
		PLUGIN_VERS=$(make -C ${STAGEDIR}${PLUGINSDIR}/${PLUGIN} ${PLUGIN_ARGS} -v PLUGIN_PKGVERSION)

		for REMOVED in ${@}; do
			if [ ${REMOVED} = ${PLUGIN_NAME} ]; then
				# make sure a subsequent build of the
				# same package goes through by removing
				# it while it may have been rebuilt on
				# another branch
				remove_packages ${STAGEDIR} ${REMOVED}
			fi
		done

		if search_packages ${STAGEDIR} ${PLUGIN_NAME} ${PLUGIN_VERS} ${BRANCH}; then
			# already built
			continue
		fi

		install_packages ${STAGEDIR} ${PLUGIN_DEPS}
		custom_packages ${STAGEDIR} ${PLUGINSDIR}/${PLUGIN} \
		    "${PLUGIN_ARGS}" ${PLUGIN_NAME} ${PLUGIN_VERS} ${BRANCH}
	done
done

bundle_packages ${STAGEDIR} ${SELF}
