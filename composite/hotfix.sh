#!/bin/sh

# Copyright (c) 2017-2024 Franco Fichtner <franco@opnsense.org>
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

TARGET=${1}
MSGS=

set -e

run_stage()
{
	STAGE=${1}
	ARGS=${2}
	ENV=${3}

	if [ -z "${ARGS}" ]; then
		return
	fi

	make ${STAGE}-${ARGS} PORTSENV="${ENV}"

	if [ -s ${STAGEDIR}/.pkg-msg ]; then
		MSGS="${MSGS}$(cat ${STAGEDIR}/.pkg-msg)
"
	fi
}

eval "$(make print-PRODUCT_CORES,PRODUCT_PLUGINS,STAGEDIR)"

if [ -z "${TARGET}" ]; then
	# run everything except ports in hotfix mode
	for STAGE in plugins core packages; do
		run_stage ${STAGE} hotfix
	done
elif [ "${TARGET}" = "plugins" -o "${TARGET}" = "core" -o \
    "${TARGET}" = "ports" ]; then
	if [ "${TARGET}" != "ports" ]; then
		# force a full rebuild of non-ports
		run_stage clean ${TARGET}
	fi

	run_stage ${TARGET} hotfix "MISMATCH=no ${PORTSENV}"

	# do not immediately echo what was being printed
	MSGS=
else
	ARG_PORTS=
	ARG_PLUGINS=
	ARG_CORE=

	# figure out which stage a package belongs to
	for PACKAGE in $(echo ${TARGET} | tr ',' ' '); do
		if [ -z "${PRODUCT_CORES%%*"${PACKAGE}"*}" ]; then
			if [ -n "${ARG_CORE}" ]; then
				ARG_CORE="${ARG_CORE},"
			fi
			ARG_CORE="${ARG_CORE}${PACKAGE}"
		elif [ "${PRODUCT_PLUGINS}" = "${PACKAGE%%-*}-*" ]; then
			if [ -n "${ARG_PLUGINS}" ]; then
				ARG_PLUGINS="${ARG_PLUGINS},"
			fi
			ARG_PLUGINS="${ARG_PLUGINS}${PACKAGE}"
		else
			if [ -n "${ARG_PORTS}" ]; then
				ARG_PORTS="${ARG_PORTS},"
			fi
			ARG_PORTS="${ARG_PORTS}${PACKAGE}"
		fi
	done

	# run all stages required for this hotfix run
	run_stage ports "${ARG_PORTS}" "DEPEND=no PRUNE=no ${PORTSENV}"
	run_stage plugins "${ARG_PLUGINS}"
	run_stage core "${ARG_CORE}"
	run_stage packages hotfix
fi

if [ -n "${MSGS}" ]; then
	echo "=============================================================="
	echo ">>> WARNING: The hotfixing provided additional info."
	echo -n "${MSGS}"
fi
