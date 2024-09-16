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

DIR=${1:-.}
BRANCH=${2:-master}
FROM=FreeBSD

if git diff --quiet ${BRANCH} ${DIR}; then
	echo ">>> Cherry-pick already complete."
	exit 0
fi

echo -n ">>> Run a git-cherry-pick or raw merge? [r/G]: "

read YN < /dev/tty
case ${YN} in
[rR])
	git diff -R ${BRANCH} ${DIR} | git apply
	git add ${DIR}
	git commit -m \
"${DIR}: sync with upstream

Taken from: ${FROM}"
	exit 0
	;;
*)
	# FALLTHROUGH
	;;
esac

COMMITS=

for HASH in $(git log --oneline ${BRANCH} ${DIR} | awk '{ print $1 }'); do
	if git diff --quiet ${HASH} ${DIR}; then
		# found no more changes
		break
	fi

	# reverse commit order for cherry-pick
	COMMITS="${HASH} ${COMMITS}"
done

for COMMIT in ${COMMITS}; do
	git cherry-pick ${COMMIT} || git cherry-pick --skip
done

if ! git diff --quiet ${BRANCH} ${DIR}; then
	echo ">>> Cherry-pick failed due to non-emtpy diff." >&2
	exit 1
fi

echo ">>> Cherry-pick finished successfully."
