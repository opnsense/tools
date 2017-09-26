#!/bin/sh

# refresh plugins and core in packages

for FLAVOUR in OpenSSL LibreSSL; do
	make clean-obj,plugins,core packages FLAVOUR=${FLAVOUR}
done

make clean-obj
