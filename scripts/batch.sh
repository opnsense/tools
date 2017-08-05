#!/bin/sh

# simple batch script for release builds

for FLAVOUR in OpenSSL LibreSSL; do
	make clean-obj
	make ${*} FLAVOUR=${FLAVOUR}
done

make clean-obj
