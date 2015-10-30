#!/bin/sh

read -t 2 SUM
[ -z "${SUM}" ] && exit 1
echo SIGNATURE
echo -n ${SUM} | openssl dgst -sign ${PRODUCT_SIGNATURE}.key -sha256 -binary
echo
echo CERT
cat ${PRODUCT_SIGNATURE}.pub
echo END
