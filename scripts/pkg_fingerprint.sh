#!/bin/sh

PUBKEY=${1}

if [ -n "${PUBKEY}" -a -f "${PUBKEY}" ]; then
	echo "function: \"sha256\""
	echo "fingerprint: \"$(sha256 -q ${PUBKEY})\""
fi
