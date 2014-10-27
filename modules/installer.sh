setup_installer(){
	cust_populate_installer_bits
}

# Install custom BSDInstaller bits for opnSense
cust_populate_installer_bits() {
	# Add lua installer items
	echo ">>> Using FreeBSD ${FREEBSD_VERSION} BSDInstaller dfuibelua structure (in $OPNSENSEBASEDIR )."

	mkdir -p $OPNSENSEBASEDIR/usr/local/share/dfuibe_lua/install/
	mkdir -p $OPNSENSEBASEDIR/scripts/
	# This is now ready for general consumption! \o/
	mkdir -p $OPNSENSEBASEDIR/usr/local/share/dfuibe_lua/conf/
	cp -r $BUILD_HOME/installer/conf \
		$OPNSENSEBASEDIR/usr/local/share/dfuibe_lua/
	# Rebrand installer!
	if [ "${PRODUCT_NAME}" != "" ]; then
		sed -i "" -e "s/name = \"pfSense\"/name = \"${PRODUCT_NAME}\"/" $OPNSENSEBASEDIR/usr/local/share/dfuibe_lua/conf/pfSense.lua
	fi
	if [ "${OPNENSE_VERSION}" != "" ]; then
		sed -i "" -e "s/version = \"1.2RC3\"/version = \"${OPNENSE_VERSION}\"/" $OPNSENSEBASEDIR/usr/local/share/dfuibe_lua/conf/pfSense.lua
	fi

	# 597_ belongs in installation directory
	cp $BUILD_HOME/installer/installer_root_dir7/597* \
		$OPNSENSEBASEDIR/usr/local/share/dfuibe_lua/install/
	# 599_ belongs in installation directory
	cp $BUILD_HOME/installer/installer_root_dir7/599* \
		$OPNSENSEBASEDIR/usr/local/share/dfuibe_lua/install/
	# 300_ belongs in dfuibe_lua/
	cp $BUILD_HOME/installer/installer_root_dir7/300* \
		$OPNSENSEBASEDIR/usr/local/share/dfuibe_lua/
	# 500_ belongs in dfuibe_lua/
	cp $BUILD_HOME/installer/installer_root_dir7/500* \
		$OPNSENSEBASEDIR/usr/local/share/dfuibe_lua/
	# Copy Centipede Networks sponsored easy-install into place
	cp -r $BUILD_HOME/installer/easy_install \
		$OPNSENSEBASEDIR/usr/local/share/dfuibe_lua/
	# Copy Centipede Networks sponsored easy-install into place
	cp $BUILD_HOME/installer/installer_root_dir7/150_easy_install.lua \
		$OPNSENSEBASEDIR/usr/local/share/dfuibe_lua/
	# Override the base installers welcome and call the Install step "Custom Install"
	cp $BUILD_HOME/installer/installer_root_dir7/200_install.lua \
		$OPNSENSEBASEDIR/usr/local/share/dfuibe_lua/
	# Copy custom 950_reboot.lua script which touches /tmp/install_complete
	cp $BUILD_HOME/installer/installer_root_dir7/950_reboot.lua \
		$OPNSENSEBASEDIR/usr/local/share/dfuibe_lua/
	# Copy cleargpt.sh utility
	cp $BUILD_HOME/installer/cleargpt.sh \
		$OPNSENSEBASEDIR/usr/sbin/
	chmod a+rx $OPNSENSEBASEDIR/usr/sbin/cleargpt.sh
	# Copy installer launcher scripts
	cp $BUILD_HOME/installer/scripts/pfi $OPNSENSEBASEDIR/scripts/
	cp $BUILD_HOME/installer/scripts/lua_installer $OPNSENSEBASEDIR/scripts/lua_installer
	cp $BUILD_HOME/installer/scripts/freebsd_installer $OPNSENSEBASEDIR/scripts/
	cp $BUILD_HOME/installer/scripts/lua_installer_rescue $OPNSENSEBASEDIR/scripts/
	cp $BUILD_HOME/installer/scripts/lua_installer_rescue $OPNSENSEBASEDIR/scripts/
	cp $BUILD_HOME/installer/scripts/lua_installer_full $OPNSENSEBASEDIR/scripts/
	chmod a+rx $OPNSENSEBASEDIR/scripts/*
	mkdir -p $OPNSENSEBASEDIR/usr/local/bin/
	cp $BUILD_HOME/installer/scripts/after_installation_routines.sh \
		$OPNSENSEBASEDIR/usr/local/bin/after_installation_routines.sh
	chmod a+rx $OPNSENSEBASEDIR/scripts/*
}
