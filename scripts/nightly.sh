#!/bin/sh

# nightly build script

make clean-logs,obj > /dev/null 2>&1

for STAGE in update base kernel distfiles; do
	# we don't normally clean these stages
	time make ${STAGE} > /tmp/logs/${STAGE}.log 2>&1
done

for FLAVOUR in OpenSSL LibreSSL; do
	make clean-packages FLAVOUR=${FLAVOUR} > /dev/null 2>&1
	time make packages FLAVOUR=${FLAVOUR} \
	    > /tmp/logs/packages-${FLAVOUR}.log 2>&1
done
