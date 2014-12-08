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

git_clear ${PORTSDIR}

# If `quick' is given, do not safely strip the system,
# so that we don't have to wait to rebuild any package.
if [ "x${1}" != "xquick" ]; then
	echo ">>> Bootstrapping pkg(8)..."
	if pkg -N; then
		pkg delete -fy pkg
	fi
	make -C "${PORTSDIR}/ports-mgmt/pkg" rmconfig-recursive
	make -C "${PORTSDIR}/ports-mgmt/pkg" clean all install
	rm -rf ${PACKAGESDIR}
fi

mkdir -p ${PACKAGESDIR}

echo ">>> Building packages..."

while read PORT_NAME PORT_CAT PORT_OPT; do
	if [ "${PORT_NAME}" = "#" ]; then
		continue
	fi

	echo -n ">>> Building ${PORT_NAME}... "

	if pkg query %n ${PORT_NAME} > /dev/null; then
		echo "skipped."
		continue
	fi

	# user configs linger somewhere else and override the override  :(
	make -C "${PORTSDIR}/${PORT_CAT}/${PORT_NAME}" rmconfig-recursive
	make -C "${PORTSDIR}/${PORT_CAT}/${PORT_NAME}" clean all install

	if pkg query %n ${PORT_NAME} > /dev/null; then
		# ok
	else
		echo "${PORT_NAME}: package names don't match"
		exit 1
	fi

	# when ports have been rebuild clear them from PACKAGESDIR
	rm -rf ${PACKAGESDIR}/${PORT_NAME}-*.txz
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

pkg_resolve_deps pkg

while read PORT_NAME PORT_CAT PORT_OPT; do
	if [ "${PORT_NAME}" = "#" ]; then
		continue
	fi

	pkg_resolve_deps "$(pkg info -E ${PORT_NAME})"
done < ${PORT_LIST}

# also build the meta-package
cd ${TOOLSDIR}/build && ./core.sh
