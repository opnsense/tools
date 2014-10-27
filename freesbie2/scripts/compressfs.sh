#!/bin/sh
#
# Copyright (c) 2005 Dario Freni
#
# See COPYING for licence terms.
#
# $FreeBSD$
# $Id: compressfs.sh,v 1.5 2008/05/05 21:02:57 sullrich Exp $

set -e -u

if [ -z "${LOGFILE:-}" ]; then
    echo "This script can't run standalone."
    echo "Please use launch.sh to execute it."
    exit 1
fi

# Local functions

# create_vnode ${UFSFILE} ${PARTITION} 
#
# Create a loop filesystem in file ${UFSFILE} containing files under
# ${PARTITION} directory (relative path from /)
create_vnode() {
    UFSFILE=$1; shift
    PARTITION=$1; shift

    echo "->create_vnode() ${UFSFILE} ${PARTITION}" >> ${LOGFILE}

    SOURCEDIR=${BASEDIR}/${PARTITION}
    DESTMOUNTPOINT=${CLONEDIR}/${PARTITION}

    cd $SOURCEDIR

    # Find the total dir size and initialize the vnode
    DIRSIZE=$(($(du -kd 0 | cut -f 1)))
    FSSIZE=$(($DIRSIZE + ($DIRSIZE/5)))
    rm -f ${UFSFILE}
    dd if=/dev/zero of=${UFSFILE} bs=1k count=1 seek=$((${FSSIZE} - 1)) >> ${LOGFILE} 2>&1

    DEVICE=/dev/$(mdconfig -a -t vnode -f ${UFSFILE})
    newfs -o space ${DEVICE} >> ${LOGFILE} 2>&1
    mkdir -p ${DESTMOUNTPOINT}
    mount -o noatime ${DEVICE} ${DESTMOUNTPOINT}
    echo ${DEVICE}
}

# umount_md_devices ${DEV} [ ${DEV} [ ... ] ]
#
# Umount and detach md devices passed as parameters
umount_md_devices() {
    echo "->umount_md_devices() $@" >> ${LOGFILE}
    for i in $@; do
	umount ${i}
	mdconfig -d -u ${i}
    done
}

# uzip ${UFSFILE} ${UZIPFILE}
#
# makes an uzip fs on ${UZIPFILE} starting from ${UFSFILE} and removes
# ${UFSFILE}
uzip() {
    UFSFILE=$1; shift
    UZIPFILE=$1;

    echo -n "Compressing ${UFSFILE}..."
    mkuzip -v -s 65536 -o ${UZIPFILE} ${UFSFILE} >> ${LOGFILE} 2>&1
    [ $? -ne 0 ] && print_error

    UFSSIZE=$(ls -l ${UFSFILE} | awk '{print $5}')
    UZIPSIZE=$(ls -l ${UZIPFILE} | awk '{print $5}')

    PERCENT=$(awk -v ufs=${UFSSIZE} -v uzip=${UZIPSIZE} 'BEGIN{print (100 - (100 * (uzip/ufs)));}')
    rm -f ${UFSFILE}
        
    echo " ${PERCENT}% saved"
}

# compress_system

compress_system() {
    echo ">>> Compressing ${CLONEDIR}..."
        
    if [ -z "${NO_COMPRESSEDFS:-}" ]; then   
        # Preparing loop filesystem to be compressed
		mkdir -p ${CLONEDIR}/uzip
	
		USRDEVICE=$(create_vnode ${CLONEDIR}/uzip/usr.ufs usr)
		DEVICES=${USRDEVICE}

		# When NO_UNIONFS is set, we prefer using a mdmfs var (created
		# automatically by rc.d scripts
		if [ -z "${NO_UNIONFS:-}" ]; then
	    	VARDEVICE=$(create_vnode ${CLONEDIR}/uzip/var.ufs var)
	    	DEVICES="${DEVICES} ${VARDEVICE}"
		fi
		trap "umount_md_devices ${DEVICES}; exit 1" INT
    fi

    cd ${BASEDIR}
    
    if [ -z "${NO_COMPRESSEDFS:-}" ]; then
		umount_md_devices ${DEVICES}
		trap "" INT
		uzip $CLONEDIR/uzip/usr.ufs $CLONEDIR/uzip/usr.uzip
		if [ -z "${NO_UNIONFS:-}" ]; then
	    	uzip $CLONEDIR/uzip/var.ufs $CLONEDIR/uzip/var.uzip	
		fi

		# Copy the rc script for uzip files
		cp ${LOCALDIR}/conf/rc.d/uzip ${CLONEDIR}/etc/rc.d/
		chmod 555 ${CLONEDIR}/etc/rc.d/uzip

		rm -rf $CLONEDIR/usr/*
    fi

	echo "Done!"
}

compress_system

cd ${LOCALDIR}
