#!/bin/sh

# import settings
. conf/buildtools/opnsense-build.conf
. conf/buildtools/opnsense-build-defaults.conf 

# import modules
for module in `ls modules/*.sh` 
do
	. $module
done

echo "[`date`] start ( $ARCH )"

echo ">>> Building kernel configs: $BUILD_KERNELS for FreeBSD: $SVN_BRANCH ..."
build_all_kernels
                

