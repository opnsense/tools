#!/bin/sh

# nightly build script

eval "$(make print-LOGSDIR,PRODUCT_ARCH,PRODUCT_VERSION,TARGETDIRPREFIX)"

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

if [ -z "${1}" ]; then
	for FLAVOUR in OpenSSL LibreSSL; do
		(make clean-packages FLAVOUR=${FLAVOUR} 2>&1) > /dev/null
	done
fi

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
