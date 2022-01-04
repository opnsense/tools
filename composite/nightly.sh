#!/bin/sh

# Copyright (c) 2017-2022 Franco Fichtner <franco@opnsense.org>
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

CLEAN=packages
CONTINUE=
FLAVOUR_TOP=${FLAVOUR}
LINES=400
NOERROR="distfiles options audit test"
STAGE1="update info base kernel xtools distfiles"
STAGE2="options ports plugins core audit test"
STAGENUM=0

eval "$(make print-LOGSDIR,PRODUCT_ARCH,PRODUCT_VERSION,STAGEDIR,TARGETDIRPREFIX)"

if [ -n "${1}" ]; then
	CLEAN=plugins,core
	CONTINUE=-nightly
fi

for RECYCLE in $(cd ${LOGSDIR}; find . -name "[0-9]*" -type f | \
    sort -r | tail -n +7); do
	(cd ${LOGSDIR}; rm ${RECYCLE})
done

mkdir -p ${LOGSDIR}/${PRODUCT_VERSION}

LOG="${LOGSDIR}/${PRODUCT_VERSION}/$(printf %02d ${STAGENUM})-clean.log"

(time make clean-obj 2>&1 || touch ${LOG}.err) > ${LOG}

if [ -f ${LOG}.err ]; then
	echo ">>> Stage clean was aborted due to an error:" > ${LOG}.err
	cat ${LOG} >> ${LOG}.err
	FLAVOUR=
	STAGE1=
fi

for STAGE in ${STAGE1}; do
	STAGENUM=$(expr ${STAGENUM} + 1)

	LOG="${LOGSDIR}/${PRODUCT_VERSION}/$(printf %02d ${STAGENUM})-${STAGE}.log"

	# we don't normally clean these stages
	(time make ${STAGE} 2>&1 || touch ${LOG}.err) > ${LOG}

	if [ -f ${LOG}.err ]; then
		echo ">>> Stage ${STAGE} was aborted due to an error, last ${LINES} lines as follows:" > ${LOG}.err
		tail -n ${LINES} ${LOG} >> ${LOG}.err

		if [ -z "${NOERROR%%*"${STAGE}"*}" ]; then
			# continue during opportunistic stages
			continue
		fi

		FLAVOUR=
		break
	else
		tail -n ${LINES} ${LOG} >> ${LOG}.ok
	fi
done

STAGENUM=$(expr ${STAGENUM} + 1)

for _FLAVOUR in ${FLAVOUR}; do
	LOG="${LOGSDIR}/${PRODUCT_VERSION}/$(printf %02d ${STAGENUM})-clean-${_FLAVOUR}.log"
	(time make clean-${CLEAN} FLAVOUR=${_FLAVOUR} 2>&1 || touch ${LOG}.err) > ${LOG}

	if [ -f ${LOG}.err ]; then
		echo ">>> Stage clean-${_FLAVOUR} was aborted due to an error:" > ${LOG}.err
		cat ${LOG} >> ${LOG}.err

		___FLAVOUR=

		for __FLAVOUR in ${FLAVOUR}; do
			if [ ${__FLAVOUR} != ${_FLAVOUR} ]; then
				___FLAVOUR="${___FLAVOUR} ${__FLAVOUR}"
			fi
		done

		FLAVOUR=${___FLAVOUR}
	fi
done

for STAGE in ${STAGE2}; do
	STAGENUM=$(expr ${STAGENUM} + 1)

	for _FLAVOUR in ${FLAVOUR}; do
		LOG="${LOGSDIR}/${PRODUCT_VERSION}/$(printf %02d ${STAGENUM})-${STAGE}-${_FLAVOUR}.log"
		(time make ${STAGE}${CONTINUE} FLAVOUR=${_FLAVOUR} 2>&1 || touch ${LOG}.err) > ${LOG} &
	done

	wait

	for _FLAVOUR in ${FLAVOUR}; do
		LOG="${LOGSDIR}/${PRODUCT_VERSION}/$(printf %02d ${STAGENUM})-${STAGE}-${_FLAVOUR}.log"
		if [ -f ${LOG}.err ]; then
			echo ">>> Stage ${STAGE}-${_FLAVOUR} was aborted due to an error, last ${LINES} lines as follows:" > ${LOG}.err
		        tail -n ${LINES} ${LOG} >> ${LOG}.err

			if [ -z "${NOERROR%%*"${STAGE}"*}" ]; then
				# continue during opportunistic stages
				continue
			fi

			___FLAVOUR=

			for __FLAVOUR in ${FLAVOUR}; do
				if [ ${__FLAVOUR} != ${_FLAVOUR} ]; then
					___FLAVOUR="${___FLAVOUR} ${__FLAVOUR}"
				fi
			done

			FLAVOUR=${___FLAVOUR}
		else
			tail -n ${LINES} ${LOG} >> ${LOG}.ok
		fi
	done
done

FLAVOUR=${FLAVOUR_TOP}

tar -C ${TARGETDIRPREFIX} -cJf \
    ${LOGSDIR}/${PRODUCT_VERSION}-${PRODUCT_ARCH}.txz \
    ${LOGSDIR##${TARGETDIRPREFIX}/}/${PRODUCT_VERSION}

rm -rf ${LOGSDIR}/latest
mv ${LOGSDIR}/${PRODUCT_VERSION} ${LOGSDIR}/latest

(make upload-log SERVER=${SERVER} UPLOADDIR=${UPLOADDIR} \
    VERSION=${PRODUCT_VERSION} 2>&1) > /dev/null
