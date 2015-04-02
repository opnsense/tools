#!/bin/sh

read -t 2 SUM
[ -z "${SUM}" ] && exit 1
echo SIGNATURE
echo -n ${SUM} | openssl dgst -sign /root/repo.key -sha256 -binary
echo
echo CERT
cat /root/repo.pub
echo END
