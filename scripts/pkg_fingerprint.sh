#!/bin/sh

if [ -f /root/repo.pub ]; then
	echo "function: \"sha256\""
	echo "fingerprint: \"$(sha256 -q /root/repo.pub)\""
fi
