#!/bin/sh

# Copyright (c) 2024-2026 Franco Fichtner <franco@opnsense.org>
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

FROM=FreeBSD
SELF=sync

. ./common.sh

SYNCBRANCH=${SYNCBRANCH:-"${PORTSBRANCH}"}
SYNCDIR=${SYNCDIR:-"${PORTSDIR}"}

GIT="git -C ${SYNCDIR}"
ARGS=${@}

for ARG in ${ARGS}; do
	# ARG intended as "category/name" but not strictly checked
	if [ ! -e ${SYNCDIR}/${ARG} ]; then
		echo ">>> Sync did not find the path ${ARG}" >&2
		exit 1
	fi
done

if ${GIT} diff --quiet ${SYNCBRANCH} ${ARGS}; then
	echo ">>> Sync already complete for ${ARGS}"
	exit 0
fi

COMMITS=

for HASH in $(${GIT} log --oneline ${SYNCBRANCH} ${ARGS} | \
    awk '{ print $1 }'); do
	if ${GIT} diff --quiet ${HASH} ${ARGS}; then
		# found no more changes
		break
	fi

	# reverse commit order for cherry-pick
	COMMITS="${HASH} ${COMMITS}"
done

for COMMIT in ${COMMITS}; do
	if ! ${GIT} cherry-pick ${COMMIT}; then
	        ${GIT} cherry-pick --skip
		break
	fi
done

if ! ${GIT} diff --quiet ${SYNCBRANCH} ${ARGS}; then
	echo ">>> Sync failed due to non-emtpy diff for ${ARGS}" >&2
	exit 1
fi

echo ">>> Sync succeeded for ${ARGS}"
