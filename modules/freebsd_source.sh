# checkout / update freebsd source
run_freebsd_source(){
	# create directories
	if [ ! -d "${SRCDIR}" ]; then   
		mkdir -p ${SRCDIR}
	fi

	echo  ">>> checkout freebsd source and apply patches" 
	checkout_freebsd_source
	apply_patches
}

#
# checkout freebsd sources
#
checkout_freebsd_source() {
	local _SVN_BRANCH=${SVN_BRANCH:-"master"}
	local _CLONE=1

	echo ">>> Removing old patch rejects..."
	find $SRCDIR -name "*.rej" -exec rm {} \;
	echo ">>> Removing original files ..."
	find $SRCDIR -name "*.orig" | sed 's/.orig//g' | xargs rm -f
	find $SRCDIR -name "*.orig" | xargs rm -f
	
	if [ -d "${SRCDIR}/.git" ]; then
		CUR_BRANCH=$(cd ${SRCDIR} && git branch | grep '^\*' | cut -d' ' -f2)
		if [ "${CUR_BRANCH}" = "${_SVN_BRANCH}" ]; then
			_CLONE=0
			( cd ${SRCDIR} && git fetch origin; git reset --hard; git clean -fxd; git rebase origin/${_SVN_BRANCH} ) 2>&1 | grep -C3 -i 'error'
		else
			rm -rf ${SRCDIR}/* ${SRCDIR}/.git
		fi
	fi
	if [ ${_CLONE} -eq 1 ]; then
		( git clone --branch ${_SVN_BRANCH} --single-branch ${FREEBSD_REPO_BASE} ${SRCDIR} ) 2>&1 | grep -C3 -i 'error'
	fi
}

#
# Apply opnSense patches 
#
apply_patches(){
#	TODO : remove?
#	echo ">>> Fix freebsd source includes..." 
#	fixup_freebsd_sources

	echo -n ">>> Applying patches from $OSPATCHFILE please wait..."
	# Loop through and patch files
	for LINE in `cat ${OSPATCHFILE} | grep -v "^#"`
	do
		PATCH_DEPTH=`echo $LINE | cut -d~ -f1`
		PATCH_DIRECTORY=`echo $LINE | cut -d~ -f2`
		PATCH_FILE=`echo $LINE | cut -d~ -f3`
		PATCH_FILE_LEN=`echo $PATCH_FILE | wc -c`
		MOVE_FILE=`echo $LINE | cut -d~ -f4`
		MOVE_FILE_LEN=`echo $MOVE_FILE | wc -c`
		IS_TGZ=`echo $LINE | grep -v grep | grep .tgz | wc -l`
		if [ ${PATH_FILE} == ""]; then
			
		elif [ ! -f "${OSPATCHDIR}/${PATCH_FILE}" ]; then
			echo
			echo "ERROR!  Patch file(${PATCH_FILE}) not found!  Please fix before building!"
			echo
			print_error_opns
			kill $$
		fi

		if [ $PATCH_FILE_LEN -gt "2" ]; then
			if [ $IS_TGZ -gt "0" ]; then
				(cd ${SRCDIR}/${PATCH_DIRECTORY} && tar xzvpf ${OSPATCHDIR}/${PATCH_FILE}) 2>&1 \
				| egrep -wi '(warning|error)'
			else
				(cd ${SRCDIR}/${PATCH_DIRECTORY} && patch --quiet -f ${PATCH_DEPTH} < ${OSPATCHDIR}/${PATCH_FILE} 2>&1 );
				if [ "$?" != "0" ]; then
					echo "failed to apply ${PATCH_FILE}";
				fi
			fi
		fi
		if [ $MOVE_FILE_LEN -gt "2" ]; then
			#cp ${SRCDIR}/${MOVE_FILE} ${SRCDIR}/${PATCH_DIRECTORY}
		fi
	done
	echo "Done!"

	echo ">>> Finding patch rejects..."
	REJECTED_PATCHES=`find $SRCDIR -name "*.rej" | wc -l`
	if [ $REJECTED_PATCHES -gt 0 ]; then
		echo
		echo "WARNING!  Rejected patches found!  Please fix before building!"
		echo
		find $SRCDIR -name "*.rej"
		echo
		if [ "$FREESBIE_ERROR_MAIL" != "" ]; then
			LOGFILE="/tmp/patches.failed.apply"
			find $SRCDIR -name "*.rej" > $LOGFILE
			print_error_opns

		fi
		print_error_opns
		kill $$
	fi
	
	
}

#
# copy some headers to prevent build issues 
# ( for example, multiple versions of the same lib in searchpath)
#
fixup_freebsd_sources(){
	cp $SRCDIR/lib/libnetbsd/sys/cdefs.h $SRCDIR/contrib/mtree/
	cp $SRCDIR/contrib/libarchive/libarchive_fe/err.h $SRCDIR/contrib/libarchive/cpio/
	cp $SRCDIR/contrib/libarchive/libarchive_fe/err.h $SRCDIR/contrib/libarchive/tar/
	cp $SRCDIR/contrib/nvi/common/multibyte.h $SRCDIR/contrib/nvi/regex/
	cp $SRCDIR/contrib/wpa/src/utils/uuid.h  $SRCDIR/contrib/wpa/wpa_supplicant/
	cp $SRCDIR/contrib/wpa/src/utils/uuid.h $SRCDIR/contrib/wpa/src/wps/
	cp $SRCDIR/lib/libnetbsd/sys/cdefs.h $SRCDIR/contrib/mtree/
	cp $SRCDIR/gnu/lib/libregex/regex.h $SRCDIR/gnu/usr.bin/grep/regex.h 
	cp $SRCDIR/gnu/lib/libregex/regex.h  $SRCDIR/contrib/diff/src/
	cp $SRCDIR/usr.bin/ar/ar.h $SRCDIR/usr.bin/ar/ar_cpy.h
}

