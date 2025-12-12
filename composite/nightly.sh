#!/bin/sh

# Copyright (c) 2017-2025 Franco Fichtner <franco@opnsense.org>
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

. $(dirname ${0})/util.sh

CLEAN=packages
CONTINUE=
STAGENUM=0

if [ -n "${1}" ]; then
	CLEAN=hotfix
	CONTINUE=-nightly
	PORTSENV="MISMATCH=no"
fi

# Stage 1 involves basic builds and preparation, reset progress for stage 2
STAGE1=${STAGE1:-"clean-obj update info base kernel xtools distfiles clean-${CLEAN}"}

# Stage 2 centers around ports, packages and QA for partial or full rebuild
STAGE2=${STAGE2:-"obsolete options ports plugins core audit test clean-obj"}

# Do not error out on these optional targets
NOERROR=${NOERROR:-"distfiles obsolete options audit test"}

# Number of error lines to log separately
LINES=${LINES:-400}

load_make_vars LOGSDIR PRODUCT_ARCH PRODUCT_VERSION REMOTEDIR SERVER TARGETDIRPREFIX

for RECYCLE in $(cd ${LOGSDIR}; find . -name "[0-9]*" -type f | \
    sort -r | tail -n +7); do
	(cd ${LOGSDIR}; rm ${RECYCLE})
done

mkdir -p ${LOGSDIR}/${PRODUCT_VERSION}

for STAGE in ${STAGE1}; do
	STAGENUM=$(expr ${STAGENUM} + 1)
	LOG="${LOGSDIR}/${PRODUCT_VERSION}/$(printf %02d ${STAGENUM})-${STAGE}.log"

	# do not force rebuilds by design
	(time make ${STAGE} 2>&1 || touch ${LOG}.err) > ${LOG}
	if [ -f ${LOG}.err ]; then
		echo ">>> Stage ${STAGE} was aborted due to an error, last ${LINES} lines as follows:" > ${LOG}.err
		tail -n ${LINES} ${LOG} >> ${LOG}.err

		if [ -z "${NOERROR%%*"${STAGE}"*}" ]; then
			# continue during opportunistic stages
			continue
		fi

		STAGE2=
		break
	else
		tail -n ${LINES} ${LOG} >> ${LOG}.ok
	fi
done

for STAGE in ${STAGE2}; do
	STAGENUM=$(expr ${STAGENUM} + 1)
	LOG="${LOGSDIR}/${PRODUCT_VERSION}/$(printf %02d ${STAGENUM})-${STAGE}.log"

	# do not force rebuilds only if requested by user
	(time make ${STAGE}${CONTINUE} PORTSENV=${PORTSENV} 2>&1 || \
	    touch ${LOG}.err) > ${LOG}
	if [ -f ${LOG}.err ]; then
		echo ">>> Stage ${STAGE} was aborted due to an error, last ${LINES} lines as follows:" > ${LOG}.err
	        tail -n ${LINES} ${LOG} >> ${LOG}.err

		if [ -z "${NOERROR%%*"${STAGE}"*}" ]; then
			# continue during opportunistic stages
			continue
		fi

		break
	else
		tail -n ${LINES} ${LOG} >> ${LOG}.ok
	fi
done

(make watch 2>&1) > ${LOGSDIR}/${PRODUCT_VERSION}/watch.log

tar -C ${TARGETDIRPREFIX} -cJf \
    ${LOGSDIR}/${PRODUCT_VERSION}-${PRODUCT_ARCH}.txz \
    ${LOGSDIR##${TARGETDIRPREFIX}/}/${PRODUCT_VERSION}

rm -rf ${LOGSDIR}/latest
mv ${LOGSDIR}/${PRODUCT_VERSION} ${LOGSDIR}/latest

(make upload-log SERVER=${SERVER} REMOTEDIR=${REMOTEDIR} \
    VERSION=${PRODUCT_VERSION} 2>&1) > ${LOGSDIR}/latest/upload.log

cat ${LOGSDIR}/latest/watch.log
