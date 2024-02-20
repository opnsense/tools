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

PORTSENV="DEPEND=no PRUNE=no ${PORTSENV}"
TARGET=${1%%-*}
MSGS=

set -e

eval "$(make print-STAGEDIR)"

if [ -z "${TARGET}" ]; then
	for STAGE in plugins core packages; do
		make ${STAGE}-hotfix

		if [ -s ${STAGEDIR}/.pkg-msg ]; then
			MSGS="${MSGS}$(cat ${STAGEDIR}/.pkg-msg)
"
		fi
	done
elif [ "${TARGET}" = "plugins" -o "${TARGET}" = "core" -o \
    "${TARGET}" = "plugins,core" -o "${TARGET}" = "core,plugins" ]; then
	# force a full rebuild of selected stage(s)
	make clean-${TARGET:-"hotfix"}
	for STAGE in plugins core packages; do
		make ${STAGE}-hotfix
		if [ -s ${STAGEDIR}/.pkg-msg ]; then
			MSGS="${MSGS}$(cat ${STAGEDIR}/.pkg-msg)
"
		fi
	done
elif [ "${TARGET}" = "ports" ]; then
	# force partial rebuild of out of date ports
	make ports-hotfix PORTSENV="MISMATCH=no ${PORTSENV}"
else
	# assume quick target port(s) to rebuild from ports.conf
	make ports-${1} PORTSENV="${PORTSENV}"
fi

if [ -n "${MSGS}" ]; then
	echo ">>> WARNING: The hotfixing provided additional info."
	echo -n "${MSGS}"
fi
