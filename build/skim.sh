#!/bin/sh

# Copyright (c) 2015 Franco Fichtner <franco@opnsense.org>
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

. ./common.sh && $(${SCRUB_ARGS})

export __MAKE_CONF=${PRODUCT_CONFIG}/make.conf
PORT_LIST=${PRODUCT_CONFIG}/ports.conf
FREEBSD=/usr/freebsd-ports
OPNSENSE=${PORTSDIR}

UNUSED=1
USED=1

for ARG in ${@}; do
	case ${ARG} in
	unused)
		UNUSED=1
		USED=
		;;
	used)
		UNUSED=
		USED=1
		;;
	esac
done

echo -n ">>> Gathering dependencies"

while read PORT_NAME PORT_CAT PORT_OPT; do
	if [ "$(echo ${PORT_NAME} | colrm 2)" = "#" ]; then
		continue
	fi

	echo -n "."

	PORT=${PORT_CAT}/${PORT_NAME}

	SOURCE=${OPNSENSE}
	if [ ! -d ${OPNSENSE}/${PORT} ]; then
		SOURCE=${FREEBSD}
	fi

	if [ "${PORT_OPT}" != "sync" ]; then
		PORT_DEPS=$(echo ${PORT}; make -C ${SOURCE}/${PORT} \
		    PORTSDIR=${SOURCE} all-depends-list | \
		    awk -F"${SOURCE}/" '{print $2}')
	else
		PORT_DEPS=${PORT}
	fi

	for PORT in ${PORT_DEPS}; do
		PORT_MASTER=$(make -C ${SOURCE}/${PORT} -V MASTER_PORT)
		if [ -n "${PORT_MASTER}" ]; then
			PORT_DEPS="${PORT_DEPS} ${PORT_MASTER}"
		fi
	done

	PORT_DEPS=$(echo ${PORT_DEPS} | tr ' ' '\n' | sort -u)
	PORT_MODS="${PORT_MODS} ${PORT_DEPS}"

	for PORT in ${PORT_DEPS}; do
		if [ ! -d ${FREEBSD}/${PORT} ]; then
			continue;
		fi

		diff -rq ${OPNSENSE}/${PORT} ${FREEBSD}/${PORT} \
		    > /dev/null && continue

		NEW=1
		for ITEM in ${PORTS_CHANGED}; do
			if [ ${ITEM} = ${PORT} ]; then
				NEW=0
				break;
			fi
		done
		if [ ${NEW} = 1 ]; then
			PORTS_CHANGED="${PORTS_CHANGED} ${PORT}"
		fi
	done
done < ${PORT_LIST}

echo "done"

if [ -n "${UNUSED}" ]; then
	for ENTRY in ${OPNSENSE}/*; do
		ENTRY=${ENTRY##"${OPNSENSE}/"}

		case "$(echo ${ENTRY} | colrm 2)" in
		[[:upper:]])
			continue
			;;
		*)
			;;
		esac

		if [ ! -d ${FREEBSD}/${ENTRY} ]; then
			continue;
		fi

		for PORT in ${OPNSENSE}/${ENTRY}/*; do
			PORT=${PORT##"${OPNSENSE}/"}

			if [ -e ${FREEBSD}/${PORT} ]; then
				continue;
			fi

			echo ">>> Removing ${PORT}"

			rm -fr ${OPNSENSE}/${PORT}
		done

		PORT_MODS=$(echo ${PORT_MODS} | tr ' ' '\n' | sort -u)

		for PORT in ${FREEBSD}/${ENTRY}/*; do
			PORT=${PORT##"${FREEBSD}/"}

			UNUSED=1
			for PORT_MOD in ${PORT_MODS}; do
				if [ ${PORT_MOD} = ${PORT} ]; then
					UNUSED=0
				fi
			done

			if [ ${UNUSED} = 0 ]; then
				echo ">>> Skipping ${PORT}"
				continue;
			fi

			echo ">>> Refreshing ${PORT}"

			rm -fr ${OPNSENSE}/${PORT}
			cp -r ${FREEBSD}/${PORT} ${OPNSENSE}/${PORT}
		done
	done
fi

if [ -n "${USED}" ]; then
	for PORT in ${PORTS_CHANGED}; do
		(clear && diff -ru ${OPNSENSE}/${PORT} ${FREEBSD}/${PORT} \
		    2>/dev/null || true;) | less -r

		echo -n "replace ${PORT} [y/N]: "
		read YN
		case ${YN} in
		[yY])
			rm -fr ${OPNSENSE}/${PORT}
			cp -a ${FREEBSD}/${PORT} ${OPNSENSE}/${PORT}
			;;
		esac
	done

	for ENTRY in ${FREEBSD}/*; do
		ENTRY=${ENTRY##"${FREEBSD}/"}

		case "$(echo ${ENTRY} | colrm 2)" in
		[[:upper:]])
			;;
		*)
			continue
			;;
		esac

		diff -rq ${OPNSENSE}/${ENTRY} ${FREEBSD}/${ENTRY} \
		    > /dev/null || ENTRIES="${ENTRIES} ${ENTRY}"
	done

	if [ -n "${ENTRIES}" ]; then
		(clear && for ENTRY in ${ENTRIES}; do
			diff -ru ${OPNSENSE}/${ENTRY} ${FREEBSD}/${ENTRY} \
			    2>/dev/null || true;
		done) | less -r

		echo -n "replace Infrastructure [y/N]: "
		read YN
		case ${YN} in
		[yY])
			for ENTRY in ${ENTRIES}; do
				rm -r ${OPNSENSE}/${ENTRY}
				cp -a ${FREEBSD}/${ENTRY} ${OPNSENSE}/
			done
			;;
		esac
	fi
fi
