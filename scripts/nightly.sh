#!/bin/sh

# nightly build script

(make clean-logs,obj 2>&1) > /dev/null

for STAGE in update info base kernel distfiles; do
	# we don't normally clean these stages
	(time make ${STAGE} 2>&1) > /tmp/logs/${STAGE}.log
done

for FLAVOUR in OpenSSL LibreSSL; do
	(make clean-packages FLAVOUR=${FLAVOUR} 2>&1) > /dev/null
	(time make packages FLAVOUR=${FLAVOUR} 2>&1) \
	    > /tmp/logs/packages-${FLAVOUR}.log
done
