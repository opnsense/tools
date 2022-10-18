#!/bin/sh

# Copyright (c) 2021-2022 Franco Fichtner <franco@opnsense.org>
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

SELF=options

. ./common.sh

PORTSLIST=$(list_packages "${PORTSLIST}" ${CONFIGDIR}/aux.conf ${CONFIGDIR}/ports.conf)

git_branch ${SRCDIR} ${SRCBRANCH} SRCBRANCH
git_branch ${PORTSDIR} ${PORTSBRANCH} PORTSBRANCH

setup_stage ${STAGEDIR}
setup_base ${STAGEDIR}
setup_clone ${STAGEDIR} ${PORTSDIR}
setup_clone ${STAGEDIR} ${SRCDIR}
setup_chroot ${STAGEDIR}

sh ./make.conf.sh > ${STAGEDIR}/etc/make.conf

RET=0

for PORT in ${PORTSLIST}; do
	PORT=${PORT%%@*}
	MAKE="${ENV_FILTER} chroot ${STAGEDIR} make -C ${PORTSDIR}/${PORT}"
	NAME=$(${MAKE} -v OPTIONS_NAME __MAKE_CONF=)
	DEFAULTS=$(${MAKE} -v PORT_OPTIONS __MAKE_CONF=)
	DEFINES=$(${MAKE} -v _REALLY_ALL_POSSIBLE_OPTIONS __MAKE_CONF=)

	SET=$(${MAKE} -v ${NAME}_SET)

	if [ -n "${SET}" ]; then
		for OPT in ${SET}; do
			for DEFAULT in ${DEFAULTS}; do
				if [ ${OPT} == EXAMPLES ]; then
					# ignore since defaults to off
					# but is required for acme.sh
					continue
				fi
				if [ ${OPT} == ${DEFAULT} ]; then
					echo "${PORT}: ${OPT} is set by default"
					RET=1
				fi
			done
		done
	fi

	UNSET=$(${MAKE} -v ${NAME}_UNSET)

	if [ -n "${UNSET}" ]; then
		for OPT in ${UNSET}; do
			FOUND=

			for DEFAULT in ${DEFAULTS}; do
				if [ ${OPT} = ${DEFAULT} ]; then
					FOUND=1
				fi
			done

			if [ -z "${FOUND}" ]; then
				echo "${PORT}: ${OPT} is unset by default"
				RET=1
			fi
		done
	fi

	if [ -n "${SET}${UNSET}" ]; then
		for OPT in ${SET} ${UNSET}; do
			FOUND=

			for DEFINE in ${DEFINES} ${DEFAULTS}; do
				if [ ${OPT} = ${DEFINE} ]; then
					FOUND=1
				fi
			done

			if [ -z "${FOUND}" ]; then
				echo "${PORT}: ${OPT} does not exist"
				RET=1
			fi
		done
	fi

	${MAKE} check-config
done

exit ${RET}
