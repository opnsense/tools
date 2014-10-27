#!/bin/sh

# import settings
. conf/buildtools/opnsense-build.conf
. conf/buildtools/opnsense-build-defaults.conf 

# import modules
for module in `ls modules/*.sh` 
do
	. $module
done

echo "cleanup all opnSense files"

if [ -d $OPNSENSEBASEDIR ]; then
	echo "remove $OPNSENSEBASEDIR" 
	chflags -R noschg $OPNSENSEBASEDIR
	rm -rf $OPNSENSEBASEDIR
fi

if [ -d $CLONEDIR ]; then
	echo "remove $CLONEDIR" 
	chflags -R noschg $CLONEDIR
	rm -rf $CLONEDIR
fi

if [ -d $SRCDIR ]; then
	echo "remove $SRCDIR" 
	chflags -R noschg $SRCDIR
	rm -rf $SRCDIR
fi


