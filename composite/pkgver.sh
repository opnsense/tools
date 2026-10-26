#!/bin/sh

# Copyright (c) 2026 Franco Fichtner <franco@opnsense.org>
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

VERSIONSPKG=$(make list-packages 2> /dev/null | grep All/ | sort)
VERSIONSAUX=$(make list-aux 2> /dev/null | grep All/ | sort)
TARGETS=$(echo ${1} | tr ',' ' ')

for TARGET in ${TARGETS}; do
	RESULT=$(echo "${VERSIONSPKG}" | (grep -i "/${TARGET}-[0-9]" || true))
	if [ -n "${RESULT}" ]; then
		RESULT=${RESULT##*-}
		echo "${TARGET}:" ${RESULT%.pkg} "(packages)"
		continue
	fi

	RESULT=$(echo "${VERSIONSAUX}" | (grep -i "/${TARGET}-[0-9]" || true))
	if [ -n "${RESULT}" ]; then
		RESULT=${RESULT##*-}
		echo "${TARGET}:" ${RESULT%.pkg} "(aux)"
	else
		echo "${TARGET}: N/A"
	fi
done

if [ -z ${TARGET} ]; then
	for RESULT in ${VERSIONSPKG}; do
		RESULT=${RESULT#./All/}
		TARGET=${RESULT%-*}
		RESULT=${RESULT##*-}
		if [ -n "${TARGET}" ]; then
			echo "${TARGET}:" ${RESULT%.pkg} "(packages)"
		fi
	done

	for RESULT in ${VERSIONSAUX}; do
		RESULT=${RESULT#./All/}
		TARGET=${RESULT%-*}
		RESULT=${RESULT##*-}
		if [ -n "${TARGET}" ]; then
			echo "${TARGET}:" ${RESULT%.pkg} "(aux)"
		fi
	done
fi
