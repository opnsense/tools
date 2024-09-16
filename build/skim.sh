#!/bin/sh

# Copyright (c) 2015-2022 Franco Fichtner <franco@opnsense.org>
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
SELF=skim

. ./common.sh

if [ -z "${PORTSLIST}" ]; then
	PORTSLIST=$(list_config ${CONFIGDIR}/skim.conf ${CONFIGDIR}/aux.conf \
	    ${CONFIGDIR}/ports.conf)
fi

DIFF="$(which colordiff 2> /dev/null || echo cat)"
LESS="less -R"

setup_stage ${STAGEDIR}

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

sh ./make.conf.sh > ${STAGEDIR}/make.conf
echo "${PORTSLIST}" > ${STAGEDIR}/skim
: > ${STAGEDIR}/used

PORTSCOUNT=$(wc -l ${STAGEDIR}/skim | awk '{ print $1 }')
PORTSNUM=0

echo -n ">>> Gathering dependencies:   0%"

while read PORT_ORIGIN PORT_BROKEN; do
	FLAVOR=${PORT_ORIGIN##*@}
	PORT=${PORT_ORIGIN%%@*}

	MAKE_ARGS="
__MAKE_CONF=${STAGEDIR}/make.conf
PRODUCT_ABI=${PRODUCT_ABI}
"

	if [ ${FLAVOR} != ${PORT} ]; then
		MAKE_ARGS="${MAKE_ARGS} FLAVOR=${FLAVOR}"
	fi

	SOURCE=${PORTSDIR}
	if [ ! -d ${PORTSDIR}/${PORT} ]; then
		SOURCE=${PORTSREFDIR}
	fi

	${ENV_FILTER} make -C ${SOURCE}/${PORT} \
	    PORTSDIR=${SOURCE} ${MAKE_ARGS} all-depends-list \
	    | awk -F"${SOURCE}/" '{print $2}' >> ${STAGEDIR}/used
	echo ${PORT} >> ${STAGEDIR}/used

	PORTSNUM=$(expr ${PORTSNUM} + 1)
	printf "\b\b\b\b%3s%%" \
	    $(expr \( 100 \* ${PORTSNUM} \) / ${PORTSCOUNT})
done < ${STAGEDIR}/skim

sort -u ${STAGEDIR}/used > ${STAGEDIR}/used.unique
cp ${STAGEDIR}/used.unique ${STAGEDIR}/used

while read PORT; do
	SOURCE=${PORTSDIR}
	if [ ! -d ${PORTSDIR}/${PORT} ]; then
		SOURCE=${PORTSREFDIR}
	fi

	PORT_MASTER=$(${ENV_FILTER} make -C ${SOURCE}/${PORT} \
	    -v MASTER_PORT PORTSDIR=${SOURCE} ${MAKE_ARGS})
	if [ -n "${PORT_MASTER}" ]; then
		echo ${PORT_MASTER} >> ${STAGEDIR}/used
	fi
done < ${STAGEDIR}/used.unique

sort -u ${STAGEDIR}/used > ${STAGEDIR}/used.unique
rm ${STAGEDIR}/used

echo

if [ -n "${UNUSED}" ]; then
	(cd ${PORTSDIR}; mkdir -p $(make -C ${PORTSREFDIR} -v SUBDIR))
	mkdir ${STAGEDIR}/ref

	for ENTRY in ${PORTSDIR}/[a-z]*; do
		ENTRY=${ENTRY##"${PORTSDIR}/"}

		echo ">>> Refreshing ${ENTRY}"

		if [ ! -d ${PORTSREFDIR}/${ENTRY} ]; then
			cp -R ${PORTSDIR}/${ENTRY} ${STAGEDIR}/ref
			continue
		fi

		cp -R ${PORTSREFDIR}/${ENTRY} ${STAGEDIR}/ref

		(grep "^${ENTRY}/" ${STAGEDIR}/used.unique || true) > \
		    ${STAGEDIR}/used.entry

		while read PORT; do
			rm -fr ${STAGEDIR}/ref/${PORT}
			cp -R ${PORTSDIR}/${PORT} \
			    ${STAGEDIR}/ref/$(dirname ${PORT})
		done < ${STAGEDIR}/used.entry

		rm -rf ${PORTSDIR}/${ENTRY}
		mv ${STAGEDIR}/ref/${ENTRY} ${PORTSDIR}
	done

	(
		cd ${PORTSDIR}
		git add .
		if ! git diff --quiet HEAD; then
			git commit -m \
"*/*: sync with upstream

Taken from: ${FROM}"
		fi
	)
fi

: > ${STAGEDIR}/used.changed

while read PORT; do
	if [ ! -d ${PORTSREFDIR}/${PORT} ]; then
		continue;
	fi

	diff -rq ${PORTSDIR}/${PORT} ${PORTSREFDIR}/${PORT} \
	    > /dev/null && continue

	echo ${PORT} >> ${STAGEDIR}/used.changed
done < ${STAGEDIR}/used.unique

if [ -n "${USED}" ]; then
	while read PORT; do
		clear
		(diff -Nru ${PORTSDIR}/${PORT} ${PORTSREFDIR}/${PORT} \
		    2>/dev/null || true) | ${DIFF} | ${LESS}

		echo -n ">>> Replace ${PORT} [c/e/y/N]: "
		read YN < /dev/tty
		case ${YN} in
		[yY])
			rm -fr ${PORTSDIR}/${PORT}
			cp -a ${PORTSREFDIR}/${PORT} ${PORTSDIR}/${PORT}
			;;
		[eE])
			rm -fr ${PORTSDIR}/${PORT}
			cp -a ${PORTSREFDIR}/${PORT} ${PORTSDIR}/${PORT}
			(cd ${PORTSDIR}; git checkout -p ${PORT} < /dev/tty)
			(cd ${PORTSDIR}; git add ${PORT})
			(cd ${PORTSDIR}; if ! git diff --quiet HEAD; then
				git commit -m \
"${PORT}: partially sync with upstream

Taken from: ${FROM}"
			fi)
			;;
		[cC])
			rm -fr ${PORTSDIR}/${PORT}
			cp -a ${PORTSREFDIR}/${PORT} ${PORTSDIR}/${PORT}
			(cd ${PORTSDIR}; git add ${PORT})
			(cd ${PORTSDIR}; git commit -m \
"${PORT}: sync with upstream

Taken from: ${FROM}")
			;;
		esac
	done < ${STAGEDIR}/used.changed

	for ENTRY in ${PORTSREFDIR}/[A-Z]*; do
		ENTRY=${ENTRY##"${PORTSREFDIR}/"}

		diff -rq ${PORTSDIR}/${ENTRY} ${PORTSREFDIR}/${ENTRY} \
		    > /dev/null || ENTRIES="${ENTRIES} ${ENTRY}"
	done

	if [ -n "${ENTRIES}" ]; then
		clear
		(for ENTRY in ${ENTRIES}; do
			diff -Nru ${PORTSDIR}/${ENTRY} ${PORTSREFDIR}/${ENTRY} \
			    2>/dev/null || true
		done) | ${DIFF} | ${LESS}

		echo -n ">>> Replace Framework [c/e/y/N]: "
		read YN < /dev/tty
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
			(cd ${PORTSDIR}; git checkout -p ${ENTRIES} < /dev/tty)
			(cd ${PORTSDIR}; git add ${ENTRIES})
			(cd ${PORTSDIR}; if ! git diff --quiet HEAD; then
				git commit -m \
"Framework: partially sync with upstream

Taken from: ${FROM}"
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

Taken from: ${FROM}")
			;;
		esac
	fi
fi
