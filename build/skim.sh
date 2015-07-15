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

export __MAKE_CONF=${CONFIGDIR}/make.conf

git_update ${PORTSREFDIR} origin/master

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

while read PORT_NAME PORT_CAT PORT_TYPE PORT_BROKEN; do
	if [ "$(echo ${PORT_NAME} | colrm 2)" = "#" ]; then
		continue
	fi

	echo -n "."

	PORT=${PORT_CAT}/${PORT_NAME}

	SOURCE=${PORTSDIR}
	if [ ! -d ${PORTSDIR}/${PORT} ]; then
		SOURCE=${PORTSREFDIR}
	fi

	if [ ${PORT_TYPE} != "sync" ]; then
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
		if [ ! -d ${PORTSREFDIR}/${PORT} ]; then
			continue;
		fi

		diff -rq ${PORTSDIR}/${PORT} ${PORTSREFDIR}/${PORT} \
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
done < ${CONFIGDIR}/ports.conf

echo "done"

if [ -n "${UNUSED}" ]; then
	for ENTRY in ${PORTSDIR}/*; do
		ENTRY=${ENTRY##"${PORTSDIR}/"}

		case "$(echo ${ENTRY} | colrm 2)" in
		[[:upper:]])
			continue
			;;
		*)
			;;
		esac

		if [ ! -d ${PORTSREFDIR}/${ENTRY} ]; then
			continue;
		fi

		for PORT in ${PORTSDIR}/${ENTRY}/*; do
			PORT=${PORT##"${PORTSDIR}/"}

			if [ -e ${PORTSREFDIR}/${PORT} ]; then
				continue;
			fi

			echo ">>> Removing ${PORT}"

			rm -fr ${PORTSDIR}/${PORT}
		done

		PORT_MODS=$(echo ${PORT_MODS} | tr ' ' '\n' | sort -u)

		for PORT in ${PORTSREFDIR}/${ENTRY}/*; do
			PORT=${PORT##"${PORTSREFDIR}/"}

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

			rm -fr ${PORTSDIR}/${PORT}
			cp -r ${PORTSREFDIR}/${PORT} ${PORTSDIR}/${PORT}
		done
	done
fi

if [ -n "${USED}" ]; then
	for PORT in ${PORTS_CHANGED}; do
		(clear && diff -ru ${PORTSDIR}/${PORT} ${PORTSREFDIR}/${PORT} \
		    2>/dev/null || true;) | less -r

		echo -n "replace ${PORT} [c/y/N]: "
		read YN
		case ${YN} in
		[yY])
			rm -fr ${PORTSDIR}/${PORT}
			cp -a ${PORTSREFDIR}/${PORT} ${PORTSDIR}/${PORT}
			;;
		[cC])
			rm -fr ${PORTSDIR}/${PORT}
			cp -a ${PORTSREFDIR}/${PORT} ${PORTSDIR}/${PORT}
			(cd ${PORTSDIR}; git add ${PORT})
			(cd ${PORTSDIR}; git commit -m \
"${PORT}: sync with upstream

Taken from: FreeBSD")
			;;
		esac
	done

	for ENTRY in ${PORTSREFDIR}/*; do
		ENTRY=${ENTRY##"${PORTSREFDIR}/"}

		case "$(echo ${ENTRY} | colrm 2)" in
		[[:upper:]])
			;;
		*)
			continue
			;;
		esac

		diff -rq ${PORTSDIR}/${ENTRY} ${PORTSREFDIR}/${ENTRY} \
		    > /dev/null || ENTRIES="${ENTRIES} ${ENTRY}"
	done

	if [ -n "${ENTRIES}" ]; then
		(clear && for ENTRY in ${ENTRIES}; do
			diff -ru ${PORTSDIR}/${ENTRY} ${PORTSREFDIR}/${ENTRY} \
			    2>/dev/null || true;
		done) | less -r

		echo -n "replace Framework [c/y/N]: "
		read YN
		case ${YN} in
		[yY])
			for ENTRY in ${ENTRIES}; do
				rm -r ${PORTSDIR}/${ENTRY}
				cp -a ${PORTSREFDIR}/${ENTRY} ${PORTSDIR}/
			done
			;;
		[cC])
			for ENTRY in ${ENTRIES}; do
				rm -r ${PORTSDIR}/${ENTRY}
				cp -a ${PORTSREFDIR}/${ENTRY} ${PORTSDIR}/
				(cd ${PORTSDIR}; git add ${ENTRY})
			done
			(cd ${PORTSDIR}; git commit -m \
"Framework: sync with upstream

Taken from: FreeBSD")
			;;
		esac
	fi
fi
