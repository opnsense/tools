#!/bin/sh

# Copyright (c) 2017-2019 Franco Fichtner <franco@opnsense.org>
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

eval "$(make print-LOGSDIR,PRODUCT_ARCH,PRODUCT_VERSION,STAGEDIR,TARGETDIRPREFIX)"

for RECYCLE in $(cd ${LOGSDIR}; find . -name "[0-9]*" -type f | \
    sort -r | tail -n +7); do
	(cd ${LOGSDIR}; rm ${RECYCLE})
done

(make clean-obj 2>&1) > /dev/null

mkdir -p ${LOGSDIR}/${PRODUCT_VERSION}

for STAGE in update info base kernel xtools distfiles; do
	LOG=${LOGSDIR}/${PRODUCT_VERSION}/${STAGE}.log
	# we don't normally clean these stages
	(time make ${STAGE} 2>&1) > ${LOG}
done

CLEAN=packages
if [ -n "${1}" ]; then
	CLEAN=plugins,core
fi

for FLAVOUR in OpenSSL LibreSSL; do
	(make clean-${CLEAN} FLAVOUR=${FLAVOUR} 2>&1) > /dev/null
done

for STAGE in ports plugins core test; do
	for FLAVOUR in OpenSSL LibreSSL; do
		LOG=${LOGSDIR}/${PRODUCT_VERSION}/${STAGE}-${FLAVOUR}.log
		((time make ${STAGE} FLAVOUR=${FLAVOUR} 2>&1) > ${LOG}; \
		    tail -n 1000 ${LOG} > ${LOG}.tail) &
	done

	wait
done

tar -C ${TARGETDIRPREFIX} -cJf \
    ${LOGSDIR}/${PRODUCT_VERSION}-${PRODUCT_ARCH}.txz \
    ${LOGSDIR##${TARGETDIRPREFIX}/}/${PRODUCT_VERSION}

rm -rf ${LOGSDIR}/latest
mv ${LOGSDIR}/${PRODUCT_VERSION} ${LOGSDIR}/latest

(make upload-log SERVER=${SERVER} UPLOADDIR=${UPLOADDIR} \
    VERSION=${PRODUCT_VERSION} 2>&1) > /dev/null
