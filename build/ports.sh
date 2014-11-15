#!/bin/sh

# Copyright (c) 2014 Franco Fichtner <franco@lastsummer.de>
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

. ./common.sh

cp ${TOOLSDIR}/config/current/make.conf /etc/make.conf

PORT_LIST="${TOOLSDIR}/config/current/ports"

# If `quick' is given, do not safely strip the system,
# so that we don't have to wait to rebuild any package.
if [ "x${1}" != "xquick" ]; then
	if pkg -N; then
		pkg delete -fy pkg
	fi
	rm -rf ${PACKAGESDIR}
fi

mkdir -p ${PACKAGESDIR}
git_clear ${PORTSDIR}

echo ">>> Building packages..."

while read PORT_NAME PORT_CAT PORT_OPT; do
	if [ "${PORT_NAME}" = "#" ]; then
		continue
	fi

	echo -n ">>> Building ${PORT_NAME}... "

	# bootstrapping pkg(1) is a little tricky
	# without pkg-query(1) to query for pkg...
	if [ "${PORT_NAME}" != "pkg" ]; then
		if pkg query %n ${PORT_NAME} > /dev/null; then
			echo "skipped."
			continue
		fi
	else
		if pkg -N; then
			echo "skipped."
			continue;
		fi
	fi

	# user configs linger somewhere else and override the override  :(
	make -C "${PORTSDIR}/${PORT_CAT}/${PORT_NAME}" rmconfig-recursive
	make -C "${PORTSDIR}/${PORT_CAT}/${PORT_NAME}" clean all install
done < ${PORT_LIST}

echo ">>> Creating binary packages..."

pkg_resolve_deps()
{
	local PORTS
	local DEPS
	local PORT
	local DEP

	DEPS="$(pkg info -qd ${1})"
	PORTS="${1} ${DEPS}"

	for DEP in $DEPS; do
		# recurse into hell and back
		pkg_resolve_deps ${DEP}
	done

	for PORT in $PORTS; do
		pkg create -no ${PACKAGESDIR} -f txz ${PORT}
	done
}

while read PORT_NAME PORT_CAT PORT_OPT; do
	if [ "${PORT_NAME}" = "#" ]; then
		continue
	fi

	pkg_resolve_deps "$(pkg info -E ${PORT_NAME})"
done < ${PORT_LIST}
