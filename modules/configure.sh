# run configure bits
run_configure(){

	if [ ! -d ${BUILDER_LOGS} ]; then
		mkdir -p ${BUILDER_LOGS}
	fi

	launch
	
	if ! install_required_builder_system_ports  ; then
		echo "  > Not all required ports where installed "
		echo "  > press <ctr>+c to abort script or <enter> to continue"
		read tmp
	fi
}

# Launch is ran first to setup a few variables that we need
# Imported from FreeSBIE
launch() {

	if [ ! -f /tmp/opnSense_builder_set_time ]; then
		echo ">>> Updating system clock..."
		ntpdate 0.pfsense.pool.ntp.org
		touch /tmp/opnSense_builder_set_time
	fi

	if [ "`id -u`" != "0" ]; then
	    echo "Sorry, this must be done as root."
	    kill $$
	fi

	echo ">>> Operation $0 has started at `date`"


	export ARCH=${ARCH:-`uname -p`}
	echo "--- Architecture : $ARCH"


	# Some variables can be passed to make only as environment, not as parameters.
	# usage: env $MAKE_CONF make $makeargs
	MAKE_CONF=${MAKE_CONF:-}

	if [ ! -z ${MAKEOBJDIRPREFIX:-} ]; then
	    MAKE_CONF="$MAKE_CONF MAKEOBJDIRPREFIX=${MAKEOBJDIRPREFIX}"
	fi

	# Set TARGET_ARCH_CONF_DIR
	if [ "$TARGET_ARCH" = "" ]; then 
        	export TARGET_ARCH=`uname -p`
        fi
        TARGET_ARCH_CONF_DIR=$SRCDIR/sys/${TARGET_ARCH}/conf/


	# always add these plugins to freesbie2 ( iso build )
	EXTRAPLUGINS="${EXTRAPLUGINS:-} rootmfs varmfs etcmfs"	
	
	# define package commands
        PKG_INFO="pkg info"
        PKG_QUERY="pkg query %n"
                                	
}

#
# This routine ensures any ports / binaries that the builder
# system needs are on disk and ready for execution.
#
install_required_builder_system_ports() {
	
	local error_count 
	
	error_count=0
	
	# No ports exist, use portsnap to bootstrap.
	if [ ! -d "/usr/ports/" ]; then
		echo -n  ">>> Grabbing FreeBSD port sources, please wait..."
		(/usr/sbin/portsnap fetch) 2>&1 | egrep -B3 -A3 -wi '(error)'
		(/usr/sbin/portsnap extract) 2>&1 | egrep -B3 -A3 -wi '(error)'
		echo "Done!"
	fi

	# update ports collection	
	echo -n ">>> Update ports collection..." 
	(/usr/sbin/portsnap fetch update ) 2>&1 | egrep -B3 -A3 -wi '(error)'
	echo "done"

	if [ `pkg version | grep "pkg-" | grep "=" | wc -l` = "0" ]; then
		echo -n ">>> Reinstall pkg (version mismatch)..."
		# reinstall pkg on version mismatch
		(cd /usr/ports/ports-mgmt/pkg && make BATCH=yes deinstall )
		(cd /usr/ports/ports-mgmt/pkg && make BATCH=yes install clean)
		echo "done"
	fi


        OIFS=$IFS
        IFS="
"
                
	for PKG_STRING in `cat conf/env_ports/builder_required_ports | grep -v "^#"`
	do
		PKG_STRING_T=`echo $PKG_STRING | sed "s/[ ]+/ /g"`
		CHECK_ON_DISK=`echo $PKG_STRING_T | awk '{ print $1 }'`
		PORT_LOCATION=`echo $PKG_STRING_T | awk '{ print $2 }'`
		UNSET_OPTS=`echo $PKG_STRING_T | awk '{ print $2 }' | sed 's/,/ /g'`
		if [ ! -f "$CHECK_ON_DISK" ]; then
			echo -n ">>> Building $PORT_LOCATION ..."
			(cd $PORT_LOCATION && make BATCH=yes deinstall clean) 2>&1 | egrep -B3 -A3 -wi '(error)'
			(cd $PORT_LOCATION && make ${MAKEJ_PORTS} WITHOUT="X11 DOCS EXAMPLES MAN INFO SDL ${UNSET_OPTS}" BATCH=yes FORCE_PKG_REGISTER=yes install clean) 2>&1 | egrep -B3 -A3 -wi '(error)'
			echo "Done!"
			if [ ! -f $CHECK_ON_DISK ]; then
				error_count=`echo $error_count + 1|bc`
				echo "! > Install failed ( $CHECK_ON_DISK not found )" 
			fi	
		fi
	done
	
	if [  -f /usr/local/sbin/portmaster ]; then
		(export FORCE_PKG_REGISTER=yes && /usr/local/sbin/portmaster -dBGm BATCH=1 --no-confirm --delete-packages -a )
	fi
	
	IFS=$OIFS
	
	return $error_count	

}

