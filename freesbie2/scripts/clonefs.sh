#!/bin/sh
#
# Copyright (c) 2005 Dario Freni
#
# See COPYING for licence terms.
#
# $FreeBSD$
# $Id: clonefs.sh,v 1.7 2008/05/05 22:49:19 sullrich Exp $

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

    echo -n ">>> Compressing ${UFSFILE}..."
    mkuzip -v -s 65536 -o ${UZIPFILE} ${UFSFILE} >> ${LOGFILE} 2>&1
    [ $? -ne 0 ] && print_error

    UFSSIZE=$(ls -l ${UFSFILE} | awk '{print $5}')
    UZIPSIZE=$(ls -l ${UZIPFILE} | awk '{print $5}')

    PERCENT=$(awk -v ufs=${UFSSIZE} -v uzip=${UZIPSIZE} 'BEGIN{print (100 - (100 * (uzip/ufs)));}')
    rm -f ${UFSFILE}

    echo " ${PERCENT}% saved"
}


# clone_system
#
# Clone BASEDIR content to CLONEDIR.

clone_system() {
    echo -n ">>> Cloning ${BASEDIR} to ${CLONEDIR}..."
    
    mkdir -p ${CLONEDIR}
    
	if [ `mount | grep ${CLONEDIR} | wc -l` -gt 0 ]; then
		MOUNTPOINT=`mount | grep ${CLONEDIR} | awk '{ print $3 }'`
		echo ">>> Attempting umount of $MOUNTPOINT"
		umount -f $MOUNTPOINT
		if [ `mount | grep ${CLONEDIR} | wc -l` -gt 0 ]; then
			echo ">>> ERROR! Could not umount $MOUNTPOINT"
			print_error
		fi
	fi

    if [ -d "${CLONEDIR}" ]; then
		chflags -R noschg ${CLONEDIR}
		rm -rf ${CLONEDIR}
	fi
    
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

	echo "Done!"

    cd ${BASEDIR}

    # If FILE_LIST isn't defined...
    if [ -z "${FILE_LIST:-}" ]; then
			# then copy the whole filesystem
			FBSD_VERSION=`/usr/bin/uname -r | /usr/bin/cut -d"." -f1`
			if [ "$FBSD_VERSION" -gt "7" ]; then
				echo ">>> Using TAR to clone..."
				mkdir -p ${CLONEDIR}				
				tar cf - * | ( cd /$CLONEDIR; tar xfp -)
			else
				echo ">>> Using CPIO to clone..."
				find . -print -depth | cpio -dump -l -v ${CLONEDIR} >> ${LOGFILE} 2>&1
			fi
	    else
		# else pass it to cpio
		if [ -f ${FILE_LIST} ]; then
		    echo "Using ${FILE_LIST} as source" | tee -a ${LOGFILE}
		    sed 's/^#.*//g' ${FILE_LIST} | cpio -dump -l -v ${CLONEDIR} >> ${LOGFILE} 2>&1
		else
		    echo "${FILE_LIST} is not a valid path, exiting..." | tee -a ${LOGFILE}
		    if [ -z "${NO_COMPRESSEDFS:-}" ]; then
				umount_md_devices ${DEVICES}
		    fi
		    exit 1
		fi
    fi

	if [ ! -f $CLONEDIR/sbin/init ]; then
		
	fi

    # If PRUNE_LIST file exists, delete files and dir listed in it
    if [ -n "${PRUNE_LIST:-}" ]; then
		if [ -f ${PRUNE_LIST} ]; then
		    echo ">>> Deleting files listed in ${PRUNE_LIST}" | tee -a ${LOGFILE}
		    set +e
		    (cd ${CLONEDIR} && sed 's/^#.*//g' ${PRUNE_LIST} | xargs rm -rvf >> ${LOGFILE} 2>&1)
		    if [ -z "${NO_COMPRESSEDFS:-}" ]; then
				echo ">>> Filling the uncompressed fs with zeros to compress better"
				echo ">>> Don't worry if you see a 'filesystem full' message here"
				zerofile=$(env TMPDIR=${CLONEDIR}/usr mktemp -t zero)
				dd if=/dev/zero of=${zerofile} >> ${LOGFILE} 2>&1
				rm ${zerofile}
		    fi
		    set -e
		else
		    echo "${PRUNE_LIST} isn't a regular file, skipping file deletion" | tee -a ${LOGFILE}
		fi
    fi

    if [ -z "${NO_UNIONFS:-}" ]; then
        # Preparing unionfs environment
		mkdir -p ${CLONEDIR}/dist ${CLONEDIR}/mnt/union

        # Declaring dirs to be union'ed. UNION_DIRS contain all the
        # directories to be union'ed. UNION_DIRS_MTREE specify which
        # directories should recover permissions (perhaps lost by
        # the iso filesystem e.g.: etc, root)

		UNION_DIRS=${UNION_DIRS:-"etc usr root var"}
		UNION_DIRS_MTREE=${UNION_DIRS_MTREE:-"etc root"}

		rm -f ${CLONEDIR}/dist/uniondirs
        for dir in ${UNION_DIRS}; do
	    	echo ${dir} >> ${CLONEDIR}/dist/uniondirs
        done

		for dir in ${UNION_DIRS_MTREE}; do
			# Saving directory structure 
		    mtree -Pcp ${BASEDIR}/${dir} > ${CLONEDIR}/dist/${dir}.dirs
		done
    fi
    
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
	fi

	if [ -z "${NO_UNIONFS:-}" ]; then
		# Copy the rc script for unionfs
		cp ${LOCALDIR}/conf/rc.d/unionfs ${CLONEDIR}/etc/rc.d/
		chmod 555 ${CLONEDIR}/etc/rc.d/unionfs
    fi

}

clone_system

cd ${LOCALDIR}
