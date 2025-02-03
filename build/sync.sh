#!/bin/sh

# Copyright (c) 2024 Franco Fichtner <franco@opnsense.org>
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

GIT="git -C ${PORTSDIR}"

for ARG in ${@}; do
	# ARG should be "category/name" but not strictly checked

	if [ ! -d ${PORTSDIR}/${ARG} ]; then
		echo ">>> Sync did not find the port ${ARG}" >&2
		exit 1
	fi

	if ${GIT} diff --quiet ${PORTSBRANCH} ${ARG}; then
		echo ">>> Sync already complete for ${ARG}"
		continue
	fi


	COMMITS=

	for HASH in $(${GIT} log --oneline ${PORTSBRANCH} ${ARG} | \
	    awk '{ print $1 }'); do
		if ${GIT} diff --quiet ${HASH} ${ARG}; then
			# found no more changes
			break
		fi

		# reverse commit order for cherry-pick
		COMMITS="${HASH} ${COMMITS}"
	done

	FAILED=

	for COMMIT in ${COMMITS}; do
		if ! (${GIT} cherry-pick ${COMMIT} || \
		    ${GIT} cherry-pick --skip); then
			FAILED=yes
			break
		fi
	done

	if [ -n "${FAILED}" ]; then
		${GIT} diff -R ${PORTSBRANCH} ${ARG} | ${GIT} apply
		${GIT} add ${ARG}
		${GIT} commit -m \
"${ARG}: sync with upstream

Taken from: ${FROM}"
	fi

	if ! ${GIT} diff --quiet ${PORTSBRANCH} ${ARG}; then
		echo ">>> Sync failed due to non-emtpy diff for ${ARG}" >&2
		exit 1
	fi

	echo ">>> Sync succeeded for ${ARG}"
done
