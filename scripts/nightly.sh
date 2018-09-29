#!/bin/sh

# nightly build script

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

	if [ ${STAGE} != "ports" ]; then
		continue
	fi

	# Find out which packages have been built but
	# ultimately discarded.  We want to know this to
	# put them on a list to keep them temporarily in
	# order to speed up the build further:

	DELETED="Deleting.files.for"
	CREATED="Creating.package.for"
	TMPFILE="${STAGEDIR}/.portpost"

	for FLAVOUR in OpenSSL LibreSSL; do
		LOG=${LOGSDIR}/${PRODUCT_VERSION}/${STAGE}-${FLAVOUR}.log

		echo ">>> Discarded intermediate packages:" > ${TMPFILE}
		grep ${DELETED} ${LOG} | awk '{ print $5 }' | \
		    cut -f1 -d':' | sort >> ${TMPFILE}

		for BUILT in $(grep ${CREATED} ${LOG} | \
		    awk '{ print $4 }' | sort -u); do
			grep -v "^${BUILT}$" ${TMPFILE} > ${TMPFILE}.next
			mv ${TMPFILE}.next ${TMPFILE}
		done

		mv ${TMPFILE} ${LOG}.post
	done
done

tar -C ${TARGETDIRPREFIX} -cJf \
    ${LOGSDIR}/${PRODUCT_VERSION}-${PRODUCT_ARCH}.txz \
    ${LOGSDIR##${TARGETDIRPREFIX}/}/${PRODUCT_VERSION}

rm -rf ${LOGSDIR}/latest
mv ${LOGSDIR}/${PRODUCT_VERSION} ${LOGSDIR}/latest

(make upload-log SERVER=${SERVER} UPLOADDIR=${UPLOADDIR} \
    VERSION=${PRODUCT_VERSION} 2>&1) > /dev/null
