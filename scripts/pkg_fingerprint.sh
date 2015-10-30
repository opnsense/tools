#!/bin/sh

if [ -f ${PRODUCT_SIGNATURE}.pub ]; then
	echo "function: \"sha256\""
	echo "fingerprint: \"$(sha256 -q ${PRODUCT_SIGNATURE}.pub)\""
fi
