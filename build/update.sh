#!/bin/sh

# Copyright (c) 2017-2023 Franco Fichtner <franco@opnsense.org>
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

SELF=update

. ./common.sh

if [ -n "${VERSION}" -a -n "${EXTRABRANCH}" ]; then
	echo ">>> Cannot check out VERSION=${VERSION} while using EXTRABRANCH=${EXTRABRANCH}"
	exit 1
fi

ARGS=${@}
if [ -z "${ARGS}" ]; then
	ARGS="core plugins ports src tools"
fi

for ARG in ${ARGS}; do
	URL=

	case ${ARG} in
	core)
		BRANCHES="${EXTRABRANCH} ${COREBRANCH}"
		DIR=${COREDIR}
		;;
	plugins)
		BRANCHES="${EXTRABRANCH} ${PLUGINSBRANCH}"
		DIR=${PLUGINSDIR}
		;;
	ports)
		BRANCHES=${PORTSBRANCH}
		DIR=${PORTSDIR}
		;;
	portsref)
		BRANCHES=${PORTSREFBRANCH}
		DIR=${PORTSREFDIR}
		URL=${PORTSREFURL}
		;;
	src)
		BRANCHES=${SRCBRANCH}
		DIR=${SRCDIR}
		;;
	tools)
		BRANCHES=${TOOLSBRANCH}
		DIR=${TOOLSDIR}
		;;
	*)
		continue
		;;
	esac

	git_clone ${DIR} "${URL}"
	git_fetch ${DIR}
	for BRANCH in ${BRANCHES}; do
		git_pull ${DIR} ${BRANCH}
	done

	if [ -n "${VERSION}" ]; then
		git_tag ${DIR} ${VERSION}
		git_pull ${DIR} ${BRANCHES}
		git_reset ${DIR}
	fi
done
