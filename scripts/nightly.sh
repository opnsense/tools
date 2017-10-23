#!/bin/sh

# nightly build script

eval "$(make print-LOGSDIR,PRODUCT_VERSION)"

for DIR in $(find ${LOGSDIR} -type d -depth 1); do
	DIR=$(basename ${DIR})
	tar -C ${LOGSDIR} -czf ${LOGSDIR}/${DIR}.tgz ${DIR} \
            && rm -r ${LOGSDIR}/${DIR}
done

(make clean-obj 2>&1) > /dev/null

mkdir -p ${LOGSDIR}/${PRODUCT_VERSION}
(cd ${LOGSDIR}; ln -sfn ${PRODUCT_VERSION} latest)

for STAGE in update info base kernel xtools distfiles; do
	# we don't normally clean these stages
	(time make ${STAGE} 2>&1) > ${LOGSDIR}/${PRODUCT_VERSION}/${STAGE}.log
done

for FLAVOUR in OpenSSL LibreSSL; do
	if [ -z "${1}" ]; then
		(make clean-packages FLAVOUR=${FLAVOUR} 2>&1) > /dev/null
	fi
	(time make packages FLAVOUR=${FLAVOUR} 2>&1) \
	    > ${LOGSDIR}/${PRODUCT_VERSION}/packages-${FLAVOUR}.log
	(time make test FLAVOUR=${FLAVOUR} 2>&1) \
	    > ${LOGSDIR}/${PRODUCT_VERSION}/test-${FLAVOUR}.log
done
