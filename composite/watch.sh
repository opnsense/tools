#!/bin/sh

# Copyright (c) 2022-2023 Franco Fichtner <franco@opnsense.org>
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

. $(dirname ${0})/util.sh

load_make_vars LOGSDIR

CURRENTDIR=$(find -s ${LOGSDIR} -type d -depth 1 \! -name latest | tail -n1)
LOGSTEP=${1}

if [ -z "${CURRENTDIR}" ]; then
	echo "No logs were found"
	return
fi

if [ -z "${LOGSTEP}" ]; then
	echo nightly build $(basename ${CURRENTDIR})
	echo ==========================
	for CURRENTLOG in $(find -s ${CURRENTDIR} -name "??-*.log"); do
		CURRENTRET=running
		if [ -f ${CURRENTLOG}.ok ]; then
			CURRENTRET=ok
		elif [ -f ${CURRENTLOG}.err ]; then
			CURRENTRET=error
		fi
		CURRENTLOG=${CURRENTLOG#"${CURRENTDIR}/"}
		CURRENTLOG=${CURRENTLOG%.log}
		CURRENTLOG=${CURRENTLOG#*-}
		echo ${CURRENTLOG}: ${CURRENTRET}
	done
else
	for CURRENTLOG in $(find ${CURRENTDIR} -name "??-${LOGSTEP}.log"); do
		if [ -f ${CURRENTLOG}.ok -o -f ${CURRENTLOG}.err ]; then
			less ${CURRENTLOG}
		else
			tail -f ${CURRENTLOG}
		fi
		break
	done
fi
