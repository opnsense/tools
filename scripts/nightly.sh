#!/bin/sh

# nightly build script

VERSION=$(date '+%Y%m%d%H%M')
LOGSDIR="/tmp/logs"

for DIR in $(find ${LOGSDIR} -type d -depth 1); do
	DIR=$(basename ${DIR})
	tar -C ${LOGSDIR} -czf ${LOGSDIR}/${DIR}.tgz ${DIR} \
            && rm -r ${LOGSDIR}/${DIR}
done

(make clean-obj 2>&1) > /dev/null

mkdir -p ${LOGSDIR}/${VERSION}
(cd ${LOGSDIR}; ln -sfn ${VERSION} latest)

for STAGE in update info base kernel xtools distfiles; do
	# we don't normally clean these stages
	(time make ${STAGE} 2>&1) > ${LOGSDIR}/${VERSION}/${STAGE}.log
done

for FLAVOUR in OpenSSL LibreSSL; do
	(make clean-packages FLAVOUR=${FLAVOUR} 2>&1) > /dev/null
	(time make packages FLAVOUR=${FLAVOUR} 2>&1) \
	    > ${LOGSDIR}/${VERSION}/packages-${FLAVOUR}.log
	(time make test FLAVOUR=${FLAVOUR} 2>&1) \
	    > ${LOGSDIR}/${VERSION}/test-${FLAVOUR}.log
done
