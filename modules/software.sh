setup_software(){
	install_pbi_tools
	install_bsdinstaller
	deploy_opnsense_ports
	install_opnsense_ports
}

# deploy opnsense custom ports
deploy_opnsense_ports(){
	echo ">>> deploy opnsense custom ports to system"
	(cd $OPNSENSE_PORTS && ./deploy.sh )	
}

# install bsd installer 
install_bsdinstaller(){
	if [ `pkg info | grep bsdinst | wc -l` -le 0 ]; then
		# unpack bsd installer sources
		echo ">>> Unpack BSDinstaller sources into  $BUILD_HOME/work"
		cd $BUILD_HOME/work
		tar xzf $BUILD_HOME/source/bsd_installer.tar.gz -C .

		cd $BUILD_HOME/work/installer/scripts/build
		mkdir -p /usr/ports/packages/All  2>/dev/null
		mkdir -p /usr/ports/packages/Old  2>/dev/null

		cat $BUILD_HOME/conf/bsdinstaller/build.conf | sed 's,<opnsense_BUILD_HOME>,$BUILD_HOME,g' > $BUILD_HOME/work/installer/scripts/build/build.conf 

		echo -n ">>> Creating installer tarballs..."
		(cd $BUILD_HOME/work/installer/scripts/build  && ./create_installer_tarballs.sh) 2>&1 | egrep -B3 -A3 -wi '(warning|error)'
		echo "Done!"

		echo -n ">>> Copying ports to the ports directory..."
		(cd $BUILD_HOME/work/installer/scripts/build  && ./copy_ports_to_portsdir.sh) 2>&1 | egrep -B3 -A3 -wi '(warning|error)'
		echo "Done!"

		echo -n ">>> Rebuilding BSDInstaller..."
		(export BATCH=yes && cd $BUILD_HOME/work/installer/scripts/build  && sh ./build_installer_packages.sh) 2>&1 | egrep -B3 -A3 -wi '(error)'
		echo "Done!"
		
		cd /usr/ports/sysutils/bsdinstaller
		make BATCH=yes install
	else
		echo  ">>> BSDInstaller already installed"
	fi 
}

# Installs PBI tools 
install_pbi_tools() {

	if [ ! -d "${PCBSD_PATH}" ]; then
		mkdir -p "${PCBSD_PATH}"
	fi

	CLONE=1
	if [ -d "${PCBSD_PATH}/.git" ]; then
		CUR_BRANCH=$(cd /${PCBSD_PATH} && git branch | grep '^\*' | cut -d' ' -f2)
		if [ "${CUR_BRANCH}" = "${PCBSD_BRANCH}" ]; then
			CLONE=0
			echo -n ">>> Updating PCBSD repo ..."
			( cd ${PCBSD_PATH} && git fetch origin; git reset --hard; git clean -fxd; git rebase origin/${PCBSD_BRANCH} ) 2>&1 | grep -C3 -i 'error'
			echo "Done!"
		else
			rm -rf ${PCBSD_PATH}/*
		fi
	fi

	if [ ${CLONE} -eq 1 ]; then
		echo -n ">>> Cloning PCBSD repo to ${PCBSD_PATH} ..."
		( git clone --branch ${PCBSD_BRANCH} --single-branch ${PCBSD_REPO} ${PCBSD_PATH} ) 2>&1 | grep -C3 -i 'error'
		echo "Done!"
	fi

	echo -n ">>> Installing PBI tools ..."
	( cd ${PCBSD_PATH}/src-sh/pbi-manager && sh ./install.sh ) 2>&1 | grep -C3 -i 'error'
	echo "Done!"
}

#
# check if selected port is installed 
# return 1 ( installed ) or 0 ( not installed) 
#
is_port_installed(){
	local PORT
	
	PORT="${1}"
	if pkg query %n ${PORT} >/dev/null 2>&1; then
		return 0
	else
	 	return 1
	fi	
}

#
# install a port including dependencies
# 
install_port() {
	PORT_LOCATION="${1}"
	
	
	MAKE_CONF="__MAKE_CONF=/tmp/ports_make.conf" 	
	
	BUILDLIST=$(make -C ${PORT_LOCATION} build-depends-list 2>/dev/null)	
	for DEP_PORT_LOCATION in $BUILDLIST 
	do
		DEP_PKGNAME=$(make -C $DEP_PORT_LOCATION  -V PKGNAME)
		if  ! is_port_installed $DEP_PKGNAME ; then			
			install_port $DEP_PORT_LOCATION
		fi
	done

	if [ ! -d /tmp/opnPort/buildlogs ]; then
		mkdir -p /tmp/opnPort/buildlogs
	fi
	
	if ! grep -q "$PORT_LOCATION" /tmp/portsinstalled ; then
		_PORTNAME=$(basename $PORT_LOCATION)
		echo -n ">>> Building $_PORTNAME(${PKGNAME})..."
		if ! script /tmp/opnPort/buildlogs/$_PORTNAME make ${MAKE_CONF} -C $PORT_LOCATION \
		    TARGET_ARCH=${ARCH} ${MAKEJ_PORTS} BATCH=yes FORCE_PKG_REGISTER=yes \
		    rmconfig clean build deinstall install clean 2>&1 1>/dev/null; then
			echo ">>> Building $_PORTNAME(${PKGNAME})...ERROR!" >> /tmp/pfPort_build_failures
			echo "Failed to build. Error log in /tmp/opnPort/buildlogs/$_PORTNAME."
		else
			mv /tmp/opnPort/buildlogs/$_PORTNAME /tmp/opnPort/buildlogs/$_PORTNAME.success
			echo "Done. (log in /tmp/opnPort/buildlogs/$_PORTNAME.success) "
		fi
		
		echo "$PORT_LOCATION" >> /tmp/portsinstalled
	fi

}

#
# create new make.conf for ports  ( into /tmp/ports_make.conf )
#
setup_ports_make_conf() {
		DCPUS=`sysctl kern.smp.cpus | cut -d' ' -f2`
		CPUS=`expr $DCPUS '*' 2`
		echo SUBTHREADS="${CPUS}" > /tmp/ports_make.conf
		if [ -f "${BUILD_HOME}/conf/ports/make.conf" ]; then
			cat ${BUILD_HOME}/conf/ports/make.conf >> /tmp/ports_make.conf
		fi
	
}


#
# install ports required for opnSense
#
install_opnsense_ports(){ 
	echo ">>> install opnSense ports"
	if [ -f /tmp/portsinstalled ]; then
		rm /tmp/portsinstalled
	fi
	touch /tmp/portsinstalled


	setup_ports_make_conf

	OIFS=$IFS
	IFS="
"
	for PORT in `cat $BUILD_HOME/conf/ports/buildports | grep -v "^#" |  sed -e '/^[[:blank:]]*$/d; /^[[:blank:]]#/d' `;
	do
		PORT_NAME=$(echo $PORT | awk '{ print $1 ;}')
		PORT_LOCATION=$(echo $PORT | awk '{ print $2 }')
		PORT_VERIFY_INSTALL_FILE=$(echo $PORT | awk '{ print $3 }')
		if [ -f  $PORT_VERIFY_INSTALL_FILE ]; then
			echo "  > already installed $PORT_NAME"
		else
			if [ -d $PORT_LOCATION ]; then
				PKGNAME=$(make -C $PORT_LOCATION -V PKGNAME)			
				if  `is_port_installed $PKGNAME`; then 
					echo "  > (skip)  already installed  $PORT_NAME"
				else
					echo "  > install $PKGNAME / $PORT_LOCATION" 
					install_port $PORT_LOCATION
				fi
			
			else
				echo "E>> not found $PORT_NAME / $PORT_LOCATION"
			fi
		fi 
	
	done

	IFS=$OIFS
	
}

#
# list all missing ports 
#
print_missing_ports(){
	OIFS=$IFS
	IFS="
"
	for PORT in `cat $BUILD_HOME/conf/ports/buildports | sed -e '/^[[:blank:]]*$/d; /^[[:blank:]]#/d' | grep -v "^#" `;
	do
		PORT_NAME=$(echo $PORT | awk '{ print $1 ;}')
		PORT_LOCATION=$(echo $PORT | awk '{ print $2 }')
		PORT_VERIFY_INSTALL_FILE=$(echo $PORT | awk '{ print $3 }')
		if [ ! -f  $PORT_VERIFY_INSTALL_FILE ]; then
			if [ -d $PORT_LOCATION ]; then
				PKGNAME=$(make -C $PORT_LOCATION -V PKGNAME)			
				if  `is_port_installed $PKGNAME`; then 
					echo "  > $PKGNAME installed, but not found @ $PORT_LOCATION "
				else
					echo "  > build failed for $PKGNAME / $PORT_LOCATION" 
				fi
			
			else
				echo "  > not found $PORT_NAME / $PORT_LOCATION"
			fi
		fi 
	
	done

	IFS=$OIFS

}
