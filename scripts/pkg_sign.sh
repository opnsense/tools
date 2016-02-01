#!/bin/sh

PUBKEY=${1}
PRIVKEY=${2}

read -t 2 SUM
[ -z "${SUM}" ] && exit 1
echo SIGNATURE
echo -n ${SUM} | openssl dgst -sign ${PRIVKEY} -sha256 -binary
echo
echo CERT
cat ${PUBKEY}
echo END
