# setup staging area
setup_staging_area(){

	# Allow old CUSTOMROOT to be deleted later
	if [ -d $CUSTOMROOT ]; then
		chflags -R noschg $CUSTOMROOT
	else
		mkdir -p $CUSTOMROOT
	fi
	
	echo ">>> Phase cust_populate_extra"	
	cust_populate_extra
	echo ">>> unpack opnSense software"
	unpack_opnsense_software
	echo ">>> set image -> cdrom "
	set_image_as_cdrom
	echo ">>> copy default config"
	copy_config_xml_from_conf_default
}

# Set image as a CDROM type image
set_image_as_cdrom() {
	echo cdrom > $CUSTOMROOT/etc/platform

        if [ ! -d $CUSTOMROOT/tank ]; then
	        mkdir $CUSTOMROOT/tank
        fi
                                                	
}


# Copies all extra files to the CUSTOMROOT staging
# area and ISO staging area (as needed)
cust_populate_extra() {
	mkdir -p ${CUSTOMROOT}/lib

	STRUCTURE_TO_CREATE="root etc usr/local/pkg/parse_config var/run scripts conf usr/local/share/dfuibe_installer root usr/local/bin usr/local/sbin usr/local/lib usr/local/etc usr/local/lib/lighttpd usr/bin usr/lib usr/lib32 usr/libexec usr/local usr/obj usr/pbi usr/sbin usr/share"

	for TEMPDIR in $STRUCTURE_TO_CREATE; do
		mkdir -p ${CUSTOMROOT}/${TEMPDIR}
		mkdir -p ${OPNSENSEBASEDIR}/${TEMPDIR}
	done

	echo exit > $CUSTOMROOT/root/.xcustom.sh
	touch $CUSTOMROOT/root/.hushlogin

	# bsnmpd
	mkdir -p $CUSTOMROOT/usr/share/snmp/defs/
	cp -R /usr/share/snmp/defs/ $CUSTOMROOT/usr/share/snmp/defs/

	# Make sure parse_config exists

	# Set buildtime
	if [ "${DATESTRING}" != "" ]; then
		date -j -f "%Y%m%d-%H%M" "${DATESTRING}" "+%a %b %e %T %Z %Y" > $CUSTOMROOT/etc/version.buildtime
	else
		date > $CUSTOMROOT/etc/version.buildtime
	fi

	# Record last commit info if it is available.
	if [ -f /tmp/build_commit_info.txt ]; then
		cp /tmp/build_commit_info.txt $CUSTOMROOT/etc/version.lastcommit
	fi

	# Suppress extra spam when logging in
	touch $CUSTOMROOT/root/.hushlogin

	# Setup login environment
	echo > $CUSTOMROOT/root/.shrc

	# Detect interactive logins and display the shell
	echo "if [ \`env | grep SSH_TTY | wc -l\` -gt 0 ] || [ \`env | grep cons25 | wc -l\` -gt 0 ]; then" > $CUSTOMROOT/root/.shrc
	echo "        /etc/rc.initial" >> $CUSTOMROOT/root/.shrc
	echo "        exit" >> $CUSTOMROOT/root/.shrc
	echo "fi" >> $CUSTOMROOT/root/.shrc
	echo "if [ \`env | grep SSH_TTY | wc -l\` -gt 0 ] || [ \`env | grep cons25 | wc -l\` -gt 0 ]; then" >> $CUSTOMROOT/root/.profile
	echo "        /etc/rc.initial" >> $CUSTOMROOT/root/.profile
	echo "        exit" >> $CUSTOMROOT/root/.profile
	echo "fi" >> $CUSTOMROOT/root/.profile

	# Turn off error checking
	set +e

	# Nuke CVS dirs
	find $CUSTOMROOT -type d -name CVS -exec rm -rf {} \; 2> /dev/null
	find $CUSTOMROOT -type d -name "_orange-flow" -exec rm -rf {} \; 2> /dev/null

	# Enable debug if requested
	if [ ! -z "${OPNSENSE_DEBUG:-}" ]; then
		touch ${CUSTOMROOT}/debugging
	fi
}


#
# copy opnsense base software
#
unpack_opnsense_software(){
	# copy opnSense base
	if [ ! -d $BUILD_HOME/../opnsense-core ]; then 
		echo "opnsource directory $BUILD_HOME/../opnsense-core missing" 
		exit 1
	fi
	echo -n "  > copy opnSense software from $BUILD_HOME/../opnsense-sources -> $CUSTOMROOT .."
	rsync -az $BUILD_HOME/../opnsense-core/* $CUSTOMROOT
	rm -rf  $CUSTOMROOT/.git*
	chown -R root:wheel $CUSTOMROOT
	echo "done"
}

# This copies the default config.xml to the location on
# disk as the primary configuration file.
copy_config_xml_from_conf_default() {
	if [ ! -f "${CUSTOMROOT}/cf/conf/config.xml" ]; then
		echo ">>> Copying config.xml from conf.default/ to cf/conf/"
		cp ${CUSTOMROOT}/conf.default/config.xml ${CUSTOMROOT}/cf/conf/
	fi

	if [ ! -L "${CUSTOMROOT}/cf/conf.default" ]; then
		# link default
		ln -s /conf.default ${CUSTOMROOT}/cf/conf.default
	fi	
	
}
