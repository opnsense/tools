#!/bin/sh

# Copyright (c) 2015-2017 Franco Fichtner <franco@opnsense.org>
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

SELF=skim

. ./common.sh

setup_stage ${STAGEDIR}

MAKE_ARGS="
__MAKE_CONF=${CONFIGDIR}/make.conf
PRODUCT_FLAVOUR=${PRODUCT_FLAVOUR}
PRODUCT_PHP=${PRODUCT_PHP}
"

if [ -z "${PORTS_LIST}" ]; then
	PORTS_LIST=$(
cat ${CONFIGDIR}/skim.conf ${CONFIGDIR}/ports.conf | \
    while read PORT_ORIGIN PORT_IGNORE; do
	eval PORT_ORIGIN=${PORT_ORIGIN}
	if [ "$(echo ${PORT_ORIGIN} | colrm 2)" = "#" ]; then
		continue
	fi
	echo ${PORT_ORIGIN}
done
)
else
	PORTS_LIST=$(
for PORT_ORIGIN in ${PORTS_LIST}; do
	echo ${PORT_ORIGIN}
done
)
fi

DIFF="$(which colordiff 2> /dev/null || echo cat)"
LESS="less -R"

git_branch ${PORTSDIR} ${PORTSBRANCH} PORTSBRANCH
git_fetch ${PORTSREFDIR}
git_pull ${PORTSREFDIR} ${PORTSREFBRANCH}
git_reset ${PORTSREFDIR} HEAD
git_reset ${PORTSDIR} HEAD

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

echo -n ">>> Gathering dependencies:   0%"

echo "${PORTS_LIST}" > ${STAGEDIR}/skim

PORTS_COUNT=$(wc -l ${STAGEDIR}/skim | awk '{ print $1 }')
PORTS_NUM=0

while read PORT_ORIGIN PORT_BROKEN; do
	PORT=${PORT_ORIGIN}

	SOURCE=${PORTSDIR}
	if [ ! -d ${PORTSDIR}/${PORT} ]; then
		SOURCE=${PORTSREFDIR}
	fi

	PORT_DEPS=$(echo ${PORT}; ${ENV_FILTER} make -C ${SOURCE}/${PORT} \
	    PORTSDIR=${SOURCE} ${MAKE_ARGS} all-depends-list | \
	    awk -F"${SOURCE}/" '{print $2}')

	for PORT in ${PORT_DEPS}; do
		PORT_MASTER=$(${ENV_FILTER} make -C ${SOURCE}/${PORT} \
		    -V MASTER_PORT PORTSDIR=${SOURCE} ${MAKE_ARGS})
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

	PORTS_NUM=$(expr ${PORTS_NUM} + 1)
	printf "\b\b\b\b%3s%%" \
	    $(expr \( 100 \* ${PORTS_NUM} \) / ${PORTS_COUNT})
done < ${STAGEDIR}/skim

echo

if [ -n "${UNUSED}" ]; then
	(cd ${PORTSDIR}; mkdir -p $(make -C ${PORTSREFDIR} -V SUBDIR))
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

	(
		cd ${PORTSDIR}
		git add .
		if ! git diff --quiet HEAD; then
			git commit -m \
"*/*: sync with upstream

Taken from: HardenedBSD"
		fi
	)
fi

if [ -n "${USED}" ]; then
	for PORT in ${PORTS_CHANGED}; do
		clear
		(diff -ru ${PORTSDIR}/${PORT} ${PORTSREFDIR}/${PORT} \
		    2>/dev/null || true) | ${DIFF} | ${LESS}

		echo -n ">>> Replace ${PORT} [c/e/y/N]: "
		read YN
		case ${YN} in
		[yY])
			rm -fr ${PORTSDIR}/${PORT}
			cp -a ${PORTSREFDIR}/${PORT} ${PORTSDIR}/${PORT}
			;;
		[eE])
			rm -fr ${PORTSDIR}/${PORT}
			cp -a ${PORTSREFDIR}/${PORT} ${PORTSDIR}/${PORT}
			(cd ${PORTSDIR}; git checkout -p ${PORT})
			(cd ${PORTSDIR}; git add ${PORT})
			(cd ${PORTSDIR}; if ! git diff --quiet HEAD; then
				git commit -m \
"${PORT}: partially sync with upstream

Taken from: HardenedBSD"
			fi)
			;;
		[cC])
			rm -fr ${PORTSDIR}/${PORT}
			cp -a ${PORTSREFDIR}/${PORT} ${PORTSDIR}/${PORT}
			(cd ${PORTSDIR}; git add ${PORT})
			(cd ${PORTSDIR}; git commit -m \
"${PORT}: sync with upstream

Taken from: HardenedBSD")
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
		clear
		(for ENTRY in ${ENTRIES}; do
			diff -ru ${PORTSDIR}/${ENTRY} ${PORTSREFDIR}/${ENTRY} \
			    2>/dev/null || true
		done) | ${DIFF} | ${LESS}

		echo -n ">>> Replace Framework [c/e/y/N]: "
		read YN
		case ${YN} in
		[yY])
			for ENTRY in ${ENTRIES}; do
				rm -r ${PORTSDIR}/${ENTRY}
				cp -a ${PORTSREFDIR}/${ENTRY} ${PORTSDIR}/
			done
			;;
		[eE])
			for ENTRY in ${ENTRIES}; do
				rm -r ${PORTSDIR}/${ENTRY}
				cp -a ${PORTSREFDIR}/${ENTRY} ${PORTSDIR}/
			done
			(cd ${PORTSDIR}; git checkout -p ${ENTRIES})
			(cd ${PORTSDIR}; git add ${ENTRIES})
			(cd ${PORTSDIR}; if ! git diff --quiet HEAD; then
				git commit -m \
"Framework: partially sync with upstream

Taken from: HardenedBSD"
			fi)
			;;
		[cC])
			for ENTRY in ${ENTRIES}; do
				rm -r ${PORTSDIR}/${ENTRY}
				cp -a ${PORTSREFDIR}/${ENTRY} ${PORTSDIR}/
				(cd ${PORTSDIR}; git add ${ENTRY})
			done
			(cd ${PORTSDIR}; git commit -m \
"Framework: sync with upstream

Taken from: HardenedBSD")
			;;
		esac
	fi
fi
