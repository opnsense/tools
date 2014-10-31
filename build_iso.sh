#!/bin/sh

# import settings
. conf/buildtools/opnsense-build.conf
. conf/buildtools/opnsense-build-defaults.conf 

# import modules
for module in `ls modules/*.sh` 
do
	. $module
done

(
	echo "[`date`] start ( $ARCH )"

	# setup/configure build environment ( modules/configure.sh ) 
	# installs ports from conf/env_ports/builder_required_ports to local system
	run_configure
	
	# setup required software and packages ( modules/software.sh )
	# - deploy custom / opnsense ports to local system ( ../opnsense-ports/deploy.sh )
	# - build all required ports for opnsense ( conf/ports/buildports )
	# retry 4 times if necessary ( fix dependancy issues ) 
	for i in 1 2 3 4 
	do
		setup_software
		error_cnt=`print_missing_ports | grep "build failed" | wc -l`
		if [ "$error_cnt" -eq "0" ]; then
			break
		else
			echo ">>> retry build ports ($i)"
		fi
	done

	# during our install we've seemed to miss some files from ports, copy manually to right location
	# todo: check and remove fixes
	fix_ports_install
	
	# checkout / prepare freebsd sources ( one time only )
	if [ ! -d $SRCDIR ]; then
		run_freebsd_source
	fi

	# setup staging area ($CUSTOMROOT)
	setup_staging_area

	# build environment  ( compile freebsd + kernels )
	run_freesbie_build

	# setup installer 
	setup_installer

	# build iso file
	freesbie_build_iso

	# list missing opnSense ports 
	echo ">>> List missing opnsense ports "
	print_missing_ports

	echo "[`date`] done "
) | tee $BUILDER_LOGS/build_iso.log

echo "log :  $BUILDER_LOGS/build_iso.log" 

