#!/bin/sh

# nightly build script

make clean-obj

for STAGE in update base kernel distfiles; do
	# we don't normally clean these stages
	time make ${STAGE} 2>&1 > /tmp/logs/${STAGE}.log
done

for FLAVOUR in OpenSSL LibreSSL; do
	make clean-packages FLAVOUR=${FLAVOUR}
	time make packages FLAVOUR=${FLAVOUR} 2>&1 > /tmp/logs/packages-${FLAVOUR}.log
done
