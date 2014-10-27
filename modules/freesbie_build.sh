run_freesbie_build(){	
	# cleanup previous installed files
	freesbie_clean_each_run

	# Prepare object directory
	echo ">>> Preparing object directory..."
	freesbie_make obj

	echo ">>> Building world for freebsd $FREEBSD_VERSION  $SVN_BRANCH ..."
	make_world

	# Ensure home target directory exists
	mkdir -p $OPNSENSEBASEDIR/home

	echo ">>> Building kernel configs: $BUILD_KERNELS for FreeBSD: $SVN_BRANCH ..."
	build_all_kernels
	
	# check for errors
	check_freesbie2_errors
	
	# overlay host libraries
	echo ">>> overlay host libraries and executables "
	cust_overlay_host_binaries

	echo ">>> Searching for packages..."
	set +e # grep could fail
	export PKGFILE=/tmp/opnspackages
	rm -f $PKGFILE
	(${PKG_INFO} | grep bsdinstaller) > $PKGFILE
	(${PKG_INFO} | grep lua) >> $PKGFILE
	set -e

	freesbie_make pkgnginstall

	# Overlay staging area
	echo ">>> Merging $CUSTOMROOT ( + extra's )" 
	freesbie_make extra

	# create md5 hashes for installed files
	create_md5_summary_file
	
	# See if php configuration script is available
	if [ -f $OPNSENSEBASEDIR/etc/rc.php_ini_setup ]; then
		echo ">>> chroot'ing and running /etc/rc.php_ini_setup"
        	chroot $OPNSENSEBASEDIR /etc/rc.php_ini_setup
	fi                


	# Create mtree summary file listing owner/permissions/sha256 and similar
	create_mtree_summary_file

	# Setup custom tcshrc prompt
	setup_tcshrc_prompt	
}

#
#  build iso image 
#
freesbie_build_iso(){
	# Prepare clonefs
	echo ">>> Cloning filesystem..."
	freesbie_make clonefs
	mkdir -p $CLONEDIR/home $CLONEDIR/etc

	echo ">>> Finalizing iso..."
	freesbie_make iso
}

# Imported from FreeSBIE
buildkernel() {
	if [ -n "${KERNELCONF:-}" ]; then
	    export KERNCONFDIR=$(dirname ${KERNELCONF})
	    export KERNCONF=$(basename ${KERNELCONF})
	elif [ -z "${KERNCONF:-}" ]; then
	    export KERNCONFDIR=${LOCALDIR}/conf/${ARCH}
	    export KERNCONF="FREESBIE"
	fi
	SRCCONFBASENAME=`basename ${SRC_CONF}`
	echo ">>> KERNCONFDIR: ${KERNCONFDIR}"
	echo ">>> ARCH:        ${ARCH}"
	echo ">>> SRC_CONF:    ${SRCCONFBASENAME}"

	LOGFILE="${BUILDER_LOGS}/kernel.${KERNCONF}.log"
	makeargs="${MAKEOPT:-} ${MAKEJ_KERNEL:-} SRCCONF=${SRC_CONF} TARGET_ARCH=${ARCH}"
	echo ">>> Builder is running the command: env $MAKE_CONF script -aq $LOGFILE make $makeargs buildkernel KERNCONF=${KERNCONF} NO_KERNELCLEAN=yo" > /tmp/freesbie_buildkernel_cmd.txt
	cd $SRCDIR
	(env $MAKE_CONF script -q $LOGFILE make $makeargs buildkernel KERNCONF=${KERNCONF} NO_KERNELCLEAN=yo || print_error_opns;) | egrep '^>>>'
	cd $BUILD_HOME

}

# Imported from FreeSBIE
installkernel() {
	# Set SRC_CONF variable if it's not already set.
	if [ -n "${KERNELCONF:-}" ]; then
	    export KERNCONFDIR=$(dirname ${KERNELCONF})
	    export KERNCONF=$(basename ${KERNELCONF})
	elif [ -z "${KERNCONF:-}" ]; then
	    export KERNCONFDIR=${LOCALDIR}/conf/${ARCH}
	    export KERNCONF="FREESBIE"
	fi
	mkdir -p ${BASEDIR}/boot
	LOGFILE="${BUILDER_LOGS}/install.kernel.${KERNCONF}.log"
	makeargs="${MAKEOPT:-} ${MAKEJ_KERNEL:-} SRCCONF=${SRC_CONF} TARGET_ARCH=${ARCH} DESTDIR=${KERNEL_DESTDIR}"
	echo ">>> Builder is running the command: env $MAKE_CONF script -aq $LOGFILE make ${makeargs:-} installkernel ${DTRACE}"  > /tmp/freesbie_installkernel_cmd.txt
	cd ${SRCDIR}
	(env $MAKE_CONF script -aq $LOGFILE make ${makeargs:-} installkernel KERNCONF=${KERNCONF} || print_error_ops;) | egrep '^>>>'
	echo ">>> Executing cd $KERNEL_DESTDIR/boot/kernel"
	gzip -f9 $KERNEL_DESTDIR/boot/kernel/kernel
	cd $BUILD_HOME
}


#
# Shortcut to FreeSBIE make command
#
freesbie_make() {
	# Make sure MAKEOBJDIRPREFIX is not set, otherwise OBJDIR will be wrong
	# and it will always rebuild everything.
	(cd ${FREESBIE_PATH} && env -u MAKEOBJDIRPREFIX CUSTOM_MAKEOBJDIRPREFIX="${MAKEOBJDIRPREFIX}" MAKEOBJDIR="${BUILDER_LOGS}/freesbie2" make $*)
}



# Mildly based on FreeSBIE
freesbie_clean_each_run() {
	echo -n ">>> Cleaning build directories: "
	if [ -d $OPNSENSEBASEDIR/tmp/ ]; then
		find $OPNSENSEBASEDIR/tmp/ -name "mountpoint*" -exec umount -f {} \;
	fi
	if [ -d "${OPNSENSEBASEDIR}" ]; then
		BASENAME=`basename ${OPNSENSEBASEDIR}`
		echo -n "$BASENAME "
	    chflags -R noschg ${OPNSENSEBASEDIR}
	    rm -rf ${OPNSENSEBASEDIR} 2>/dev/null
	fi
	if [ -d "${CLONEDIR}" ]; then
		BASENAME=`basename ${CLONEDIR}`
		echo -n "$BASENAME "
	    chflags -R noschg ${CLONEDIR}
	    rm -rf ${CLONEDIR} 2>/dev/null
	fi
	echo "Done!"
}


check_freesbie2_errors(){
	# Check for freesbie builder issues
	if [ -f ${BUILDER_LOGS}/freesbie2/.tmp_kernelbuild ]; then
	        echo "Something has gone wrong!  Press ENTER to view log file."
                read ans
                more ${BUILDER_LOGS}/freesbie2/.tmp_kernelbuild
        	exit
	fi                                
}


# overlay host binaries  
cust_overlay_host_binaries() {

	# Ensure directories exist
	# BEGIN required by gather_pfPorts_binaries_in_tgz
	mkdir -p ${OPNSENSEBASEDIR}/lib/geom
	mkdir -p ${OPNSENSEBASEDIR}/usr/local/share/rrdtool/fonts/
	mkdir -p ${OPNSENSEBASEDIR}/usr/local/share/smartmontools/
	mkdir -p ${OPNSENSEBASEDIR}/usr/local/lib/lighttpd/
	mkdir -p ${OPNSENSEBASEDIR}/usr/share/man/man8
	mkdir -p ${OPNSENSEBASEDIR}/usr/share/man/man5
	# END required by gather_pfPorts_binaries_in_tgz
	mkdir -p ${OPNSENSEBASEDIR}/bin
	mkdir -p ${OPNSENSEBASEDIR}/sbin
	mkdir -p ${OPNSENSEBASEDIR}/usr/bin
	mkdir -p ${OPNSENSEBASEDIR}/usr/sbin
	mkdir -p ${OPNSENSEBASEDIR}/usr/lib
	mkdir -p ${OPNSENSEBASEDIR}/usr/sbin
	mkdir -p ${OPNSENSEBASEDIR}/usr/libexec
	mkdir -p ${OPNSENSEBASEDIR}/usr/local/bin
	mkdir -p ${OPNSENSEBASEDIR}/usr/local/sbin
	mkdir -p ${OPNSENSEBASEDIR}/usr/local/lib
	mkdir -p ${OPNSENSEBASEDIR}/usr/local/lib/mysql
	mkdir -p ${OPNSENSEBASEDIR}/usr/local/libexec
	

	FOUND_FILES=`cat ${BUILD_HOME}/conf/copylist/copy.list| grep -v "^#"`	
	
	
	# Process base system libraries
	NEEDEDLIBS=""
	echo ">>> Populating newer binaries found on host jail/os (usr/local)..."
	for TEMPFILE in $FOUND_FILES; do
		if [ -f /${TEMPFILE} ]; then
			FILETYPE=`file /$TEMPFILE | egrep "(dynamically|shared)" | wc -l | awk '{ print $1 }'`
			mkdir -p `dirname ${OPNSENSEBASEDIR}/${TEMPFILE}`
			if [ "$FILETYPE" -gt 0 ]; then
				NEEDLIB=`ldd /${TEMPFILE} | grep "=>" | awk '{ print $3 }'`
				NEEDEDLIBS="$NEEDEDLIBS $NEEDLIB" 
				if [ ! -f ${OPNSENSEBASEDIR}/${TEMPFILE} ] || [ /${TEMPFILE} -nt ${OPNSENSEBASEDIR}/${TEMPFILE} ]; then
					cp /${TEMPFILE} ${OPNSENSEBASEDIR}/${TEMPFILE}
					chmod a+rx ${OPNSENSEBASEDIR}/${TEMPFILE}
				fi
				for NEEDL in $NEEDLIB; do
					if [ -f $NEEDL ]; then
						if [ ! -f ${OPNSENSEBASEDIR}${NEEDL} ] || [ $NEEDL -nt ${OPNSENSEBASEDIR}${NEEDL} ]; then
							if [ ! -d "$(dirname ${OPNSENSEBASEDIR}${NEEDL})" ]; then
								mkdir -p $(dirname ${OPNSENSEBASEDIR}${NEEDL})
							fi
							cp $NEEDL ${OPNSENSEBASEDIR}${NEEDL}
						fi
						if [ -d "${CLONEDIR}" ]; then
							if [ ! -f ${CLONEDIR}${NEEDL} ] || [ $NEEDL -nt ${CLONEDIR}${NEEDL} ]; then
								if [ ! -d "$(dirname ${CLONEDIR}${NEEDL})" ]; then
									mkdir -p $(dirname ${CLONEDIR}${NEEDL})
								fi
								cp $NEEDL ${CLONEDIR}${NEEDL}
							fi
						fi
					fi
				done
			else
				cp /${TEMPFILE} ${OPNSENSEBASEDIR}/$TEMPFILE
			fi
		elif [ -d /${TEMPFILE} ]; then
			# copy full directory to image
			cp -p -r /${TEMPFILE} ${OPNSENSEBASEDIR}/$TEMPFILE
		else
			if [ -f ${CUSTOMROOT}/${TEMPFILE} ]; then
				FILETYPE=`file ${CUSTOMROOT}/${TEMPFILE} | grep dynamically | wc -l | awk '{ print $1 }'`
				if [ "$FILETYPE" -gt 0 ]; then
					NEEDEDLIBS="$NEEDEDLIBS `ldd ${CUSTOMROOT}/${TEMPFILE} | grep "=>" | awk '{ print $3 }'`"
				fi
			else
				echo "Could not locate $TEMPFILE" >> ${BUILDER_LOGS}/copy.list.log
			fi
		fi
	done
	#export DONTSTRIP=1
	echo ">>> Installing collected library information, please wait..."
	# Unique the libraries so we only copy them once
	NEEDEDLIBS=`for LIB in ${NEEDEDLIBS} ; do echo $LIB ; done |sort -u`
	for NEEDLIB in $NEEDEDLIBS; do
		if [ -f $NEEDLIB ]; then
			if [ ! -f ${OPNSENSEBASEDIR}${NEEDLIB} ] || [ ${NEEDLIB} -nt ${OPNSENSEBASEDIR}${NEEDLIB} ]; then
				install ${NEEDLIB} ${OPNSENSEBASEDIR}${NEEDLIB}
			fi
			if [ -d "${CLONEDIR}" ]; then
				if [ ! -f ${CLONEDIR}${NEEDLIB} ] || [ ${NEEDLIB} -nt ${CLONEDIR}${NEEDLIB} ]; then
					install ${NEEDLIB} ${CLONEDIR}${NEEDLIB} 2>/dev/null
				fi
			fi
		fi
	done
	#unset DONTSTRIP

	if [ "X${PRUNE_LIST}" != "X" ]; then
		echo ">>> Deleting files listed in ${PRUNE_LIST}"
		(cd ${OPNSENSEBASEDIR} && sed 's/^#.*//g' ${PRUNE_LIST} | xargs rm -rvf > /dev/null 2>&1)	
	fi
		                                                
}                        


# This routine creates an mtree file that can be used to check
# and correct file permissions post-install, to correct for the
# fact that the ISO image doesn't support some permissions.
create_mtree_summary_file() {
	echo -n ">>> Creating mtree summary of files present..."
	rm -f $OPNSENSEBASEDIR/etc/installed_filesystem.mtree
	echo "#!/bin/sh" > $OPNSENSEBASEDIR/chroot.sh
	echo "cd /" >> $OPNSENSEBASEDIR/chroot.sh
	echo "/tmp" >> $OPNSENSEBASEDIR/tmp/installed_filesystem.mtree.exclude
	echo "/dev" >> $OPNSENSEBASEDIR/tmp/installed_filesystem.mtree.exclude
	echo "/usr/sbin/mtree -c -k uid,gid,mode,size,sha256digest -p / -X /tmp/installed_filesystem.mtree.exclude > /tmp/installed_filesystem.mtree" >> $OPNSENSEBASEDIR/chroot.sh
	echo "/bin/chmod 600 /tmp/installed_filesystem.mtree" >> $OPNSENSEBASEDIR/chroot.sh
	echo "/bin/mv /tmp/installed_filesystem.mtree /etc/" >> $OPNSENSEBASEDIR/chroot.sh

	chmod a+rx $OPNSENSEBASEDIR/chroot.sh
	(chroot $OPNSENSEBASEDIR /chroot.sh) 
	rm $OPNSENSEBASEDIR/chroot.sh
	echo "Done."
}

setup_tcshrc_prompt() {
	# If .tcshrc already exists, don't overwrite it.
	if [ ! -f ${OPNSENSEBASEDIR}/root/.tcshrc ]; then
		if [ ! -n ${SKIP_TCSH_PROMPT} ]; then
			echo 'set prompt="%{\033[0;1;33m%}[%{\033[0;1;37m%}`cat /etc/version`%{\033[0;1;33m%}]%{\033[0;1;33m%}%B[%{\033[0;1;37m%}%n%{\033[0;1;31m%}@%{\033[0;1;37m%}%M%{\033[0;1;33m%}]%{\033[0;1;32m%}%b%/%{\033[0;1;33m%}(%{\033[0;1;37m%}%h%{\033[0;1;33m%})%{\033[0;1;36m%}%{\033[0;1;31m%}:%{\033[0;40;37m%} "' >> ${OPNSENSEBASEDIR}/root/.tcshrc
		fi
		echo 'set autologout="0"' >> ${OPNSENSEBASEDIR}/root/.tcshrc
		echo 'set autolist set color set colorcat' >> ${OPNSENSEBASEDIR}/root/.tcshrc
		echo 'setenv CLICOLOR "true"' >> ${OPNSENSEBASEDIR}/root/.tcshrc
		echo 'setenv LSCOLORS "exfxcxdxbxegedabagacad"' >> ${OPNSENSEBASEDIR}/root/.tcshrc
		echo "alias installer /scripts/lua_installer" >> ${OPNSENSEBASEDIR}/root/.tcshrc
	fi
}


# This builds FreeBSD (make buildworld)
make_world() {

	if [ -d ${BUILDER_LOGS}/freesbie2 ]; then
		find ${BUILDER_LOGS}/freesbie2/ -name .done_installworld -exec rm {} \;
		find ${BUILDER_LOGS}/freesbie2/ -name .done_buildworld -exec rm {} \;
		find ${BUILDER_LOGS}/freesbie2/ -name .done_extra -exec rm {} \;
		find ${BUILDER_LOGS}/freesbie2/ -name .done_objdir -exec rm {} \;

		# Check if the world and kernel are already built and set
		# the NO variables accordingly
		if [ -d "${MAKEOBJDIRPREFIX}" ]; then
			ISINSTALLED=`find ${MAKEOBJDIRPREFIX}/ -name init | wc -l`
			if [ "$ISINSTALLED" -gt 0 ]; then
				export MAKE_CONF="${MAKE_CONF} NO_CLEAN=yes NO_KERNELCLEAN=yes"
			fi
		fi
	fi

	HOST_ARCHITECTURE=`uname -m`
	if [ "${HOST_ARCHITECTURE}" = "${ARCH}" ]; then
		export MAKE_CONF="${MAKE_CONF} WITHOUT_CROSS_COMPILER=yes"
	fi

	# Invoke FreeSBIE's buildworld
	freesbie_make buildworld

	# EDGE CASE #1 btxldr ############################################
	# Sometimes inbetween build_iso runs btxld seems to go missing.
	# ensure that this binary is always built and ready.
	echo ">>> Ensuring that the btxld problem does not happen on subsequent runs..."
	FBSD_VERSION=`/usr/bin/uname -r | /usr/bin/cut -d"." -f1`
	(cd $SRCDIR/usr.sbin/btxld && env ARCH=$ARCH TARGET_ARCH=${ARCH} MAKEOBJDIRPREFIX=$MAKEOBJDIRPREFIX SRCCONF=${SRC_CONF} make $MAKEJ_WORLD ${MAKE_CONF}) 2>&1 \
		| egrep -wi '(warning|error)'
	(cd $SRCDIR/sys/boot/$ARCH/btx/btx && env ARCH=$ARCH TARGET_ARCH=${ARCH} \
		MAKEOBJDIRPREFIX=$MAKEOBJDIRPREFIX SRCCONF=${SRC_CONF} make $MAKEJ_WORLD ${MAKE_CONF}) 2>&1 \
		| egrep -wi '(warning|error)'
	if [ "$ARCH" = "i386" ]; then
		(cd $SRCDIR/sys/boot/i386/pxeldr && env ARCH=$ARCH TARGET_ARCH=${ARCH} \
			MAKEOBJDIRPREFIX=$MAKEOBJDIRPREFIX SRCCONF=${SRC_CONF} make $MAKEJ_WORLD ${MAKE_CONF}) 2>&1 \
			| egrep -wi '(warning|error)'
	fi

	OSRC_CONF=${SRC_CONF}
	if [ -n "${SRC_CONF_INSTALL:-}" ]; then
		export SRC_CONF=$SRC_CONF_INSTALL
	fi

	# Invoke FreeSBIE's installworld
	freesbie_make installworld

	SRC_CONF=${OSRC_CONF}

}

# This routine will verify that the kernel has been
# installed OK to the staging area.
ensure_kernel_exists() {
	if [ ! -f "$1/boot/kernel/kernel.gz" ]; then
		echo "Could not locate $1/boot/kernel.gz"
		print_error_opns
		kill $$
	fi
	KERNEL_SIZE=`ls -la $1/boot/kernel/kernel.gz | awk '{ print $5 }'`
	if [ "$KERNEL_SIZE" -lt 3500 ]; then
		echo "Kernel $1/boot/kernel.gz appears to be smaller than it should be: $KERNEL_SIZE"
		print_error_opns
		kill $$
	fi
}



#
# 
#
fixup_kernel_options() {

	# Do not remove or move support to freesbie2/scripts/installkernel.sh

	# Cleanup self
	if [ -d ${MAKEOBJDIRPREFIX} ]; then
		find $MAKEOBJDIRPREFIX -name .done_buildkernel -exec rm {} \;
		find $MAKEOBJDIRPREFIX -name .done_installkernel -exec rm {} \;
	fi

	if [ -d "$KERNEL_DESTDIR/boot" ]; then
		rm -rf $KERNEL_DESTDIR/boot/*
	fi

	# Create area where kernels will be copied on LiveCD
	mkdir -p $OPNSENSEBASEDIR/kernels/
	# Make sure directories exist
	mkdir -p $KERNEL_DESTDIR/boot/kernel
	mkdir -p $KERNEL_DESTDIR/boot/defaults
	
	

	# Copy opnSense kernel configuration files over to $SRCDIR/sys/$ARCH/conf
	cp $BUILD_HOME/conf/kernel/$KERNCONF $KERNELCONF
	if [ ! -f "$KERNELCONF" ]; then
		echo ">>> Could not find $KERNELCONF"
		print_error_opns
	fi
	echo "" >> $KERNELCONF


	if [ "$WITH_DTRACE" = "" ]; then
		echo ">>> Not adding D-Trace to Kernel..."
	else
		echo "options KDTRACE_HOOKS" >> $KERNELCONF
		echo "options DDB_CTF" >> $KERNELCONF
	fi

	if [ "$TARGET_ARCH" = "" ]; then
		TARGET_ARCH=$ARCH
	fi

	# Add SMP and APIC options for i386 platform
	if [ "$ARCH" = "i386" ]; then
		echo "device 		apic" >> $KERNELCONF
		echo "options 		SMP"   >> $KERNELCONF
	fi

	# Add ALTQ_NOPCC which is needed for ALTQ
	echo "options		ALTQ_NOPCC" >> $KERNELCONF

	# Add SMP
	if [ "$ARCH" = "amd64" ]; then
		echo "options 		SMP"   >> $KERNELCONF
	fi
	if [ "$ARCH" = "powerpc" ]; then
		echo "options 		SMP"   >> $KERNELCONF
	fi

	# If We're on 8.3 or 10.0 and the kernel has ath support in it, make sure we have ath_pci if it's not already present.
	if [ "${FREEBSD_BRANCH}" = "RELENG_8_3" -o "${FREEBSD_BRANCH}" = "RELENG_10_0" ] && [ `/usr/bin/grep -c ath ${KERNELCONF}` -gt 0 ] && [ `/usr/bin/grep -c ath_pci ${KERNELCONF}` = 0 ]; then
		echo "device		ath_pci" >> ${KERNELCONF}
	fi
	if [ "${FREEBSD_BRANCH}" = "RELENG_8_3" -o "${FREEBSD_BRANCH}" = "RELENG_10_0" ]; then
		echo "options		ALTQ_CODEL" >> ${KERNELCONF}
	fi

	if [ "$EXTRA_DEVICES" != "" ]; then
		echo "devices	$EXTRA_DEVICES" >> $KERNELCONF
	fi
	if [ "$NOEXTRA_DEVICES" != "" ]; then
		echo "nodevices	$NOEXTRA_DEVICES" >> $KERNELCONF
	fi
	if [ "$EXTRA_OPTIONS" != "" ]; then
		echo "options	$EXTRA_OPTIONS" >> $KERNELCONF
	fi
	if [ "$NOEXTRA_OPTIONS" != "" ]; then
		echo "nooptions	$NOEXTRA_OPTIONS" >> $KERNELCONF
	fi

	# NOTE!  If you remove this, you WILL break booting!  These file(s) are read
	#        by FORTH and for some reason installkernel with DESTDIR does not
	#        copy this file over and you will end up with a blank file?
	cp $SRCDIR/sys/boot/forth/loader.conf $KERNEL_DESTDIR/boot/defaults
	if [ -f $SRCDIR/sys/$ARCH/conf/GENERIC.hints ]; then
		cp $SRCDIR/sys/$ARCH/conf/GENERIC.hints	$KERNEL_DESTDIR/boot/device.hints
	fi
	if [ -f $SRCDIR/sys/$ARCH/conf/$KERNCONF.hints ]; then
		cp $SRCDIR/sys/$ARCH/conf/$KERNCONF.hints $KERNEL_DESTDIR/boot/device.hints
	fi
	# END NOTE.

	# Danger will robinson -- 7.2+ will NOT boot if these files are not present.
	# the loader will stop at |
	touch $KERNEL_DESTDIR/boot/loader.conf

}

        
# This routine builds all pfSense related kernels
build_all_kernels() {

	# Build embedded kernel
	for BUILD_KERNEL in $BUILD_KERNELS; do
		echo ">>> Building $BUILD_KERNEL kernel..."
		unset KERNCONF
		unset KERNEL_DESTDIR
		unset KERNELCONF
		unset KERNEL_NAME
		export KERNCONF=$BUILD_KERNEL
		export KERNEL_DESTDIR="$KERNEL_BUILD_PATH/$BUILD_KERNEL"
		export KERNELCONF="${TARGET_ARCH_CONF_DIR}/$BUILD_KERNEL"

		# Common fixup code
		fixup_kernel_options
		export SRC_CONF=${SRC_CONF}
		
		
		buildkernel

		OSRC_CONF=${SRC_CONF}
		if [ -n "${SRC_CONF_INSTALL:-}" ]; then
			export SRC_CONF=$SRC_CONF_INSTALL
		fi

		echo ">>> Installing $BUILD_KERNEL kernel..."
		installkernel

		SRC_CONF=${OSRC_CONF}

		ensure_kernel_exists $KERNEL_DESTDIR

		# Nuke symbols
		echo -n ">>> Cleaning up .symbols... "
		if [ -z "${OPNSENSE_DEBUG:-}" ]; then
			echo -n "."
			find $OPNSENSEBASEDIR/ -name "*.symbols" -exec rm -f {} \;
			echo -n "."
			find $KERNEL_BUILD_PATH -name "*.symbols" -exec rm -f {} \;
		fi

		# Nuke old kernel if it exists
		find $KERNEL_BUILD_PATH -name kernel.old -exec rm -rf {} \; 2>/dev/null
		echo "done."

		# Use kernel INSTALL_NAME if it exists
		KERNEL_INSTALL_NAME=`/usr/bin/sed -e '/INSTALL_NAME/!d; s/^.*INSTALL_NAME[[:blank:]]*//' \
			${KERNELCONF} | /usr/bin/head -n 1`

		if [ -z "${KERNEL_INSTALL_NAME}" ]; then
			export KERNEL_NAME=`echo ${BUILD_KERNEL} | sed -e 's/pfSense_//; s/\.[0-9].*$//'`
		else
			export KERNEL_NAME=${KERNEL_INSTALL_NAME}
		fi

		echo -n ">>> Installing kernel to staging area... ( $KERNEL_BUILD_PATH/$BUILD_KERNEL/boot/ ->  $OPNSENSEBASEDIR/kernels/kernel_${KERNEL_NAME}.gz ) "
		(cd $KERNEL_BUILD_PATH/$BUILD_KERNEL/boot/ && tar czf $OPNSENSEBASEDIR/kernels/kernel_${KERNEL_NAME}.gz .)
		echo -n "."
		
		echo ".done"
		
		if [ "${BUILD_KERNEL}" = "${DEFAULT_KERNEL}" ]; then
			# If something is missing complain
			if [ ! -f $OPNSENSEBASEDIR/kernels/kernel_${KERNEL_NAME}.gz ]; then
				echo "The kernel archive($OPNSENSEBASEDIR/kernels/kernel_${KERNEL_NAME}.gz) to install as default does not exist"
				print_error_opns
			fi
			
			echo ">>> copy default kernel kernel_${KERNEL_NAME}.gz to $OPNSENSEBASEDIR/boot/"
			(cd $OPNSENSEBASEDIR/boot/ && tar xzf $OPNSENSEBASEDIR/kernels/kernel_${KERNEL_NAME}.gz -C $OPNSENSEBASEDIR/boot/)

			chflags -R noschg $OPNSENSEBASEDIR/boot/
		fi
	done
}
        

# This routine creates a on disk summary of all file
# checksums which could be used to verify that a file
# is indeed how it was shipped.
create_md5_summary_file() {
	echo -n ">>> Creating md5 summary of files present..."
	rm -f $OPNSENSEBASEDIR/etc/pfSense_md5.txt
	echo "#!/bin/sh" > $OPNSENSEBASEDIR/chroot.sh
	echo "find / -type f  -print0  | /usr/bin/xargs -0 /sbin/md5 >> /etc/opnSense_md5.txt" >> $OPNSENSEBASEDIR/chroot.sh
	chmod a+rx $OPNSENSEBASEDIR/chroot.sh
	(chroot $OPNSENSEBASEDIR /chroot.sh) 
	rm $OPNSENSEBASEDIR/chroot.sh
	echo "Done."
}


