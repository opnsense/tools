#!/bin/sh
#
# Copyright (c) 2005 Dario Freni
#
# See COPYING for licence terms.
#
# $FreeBSD$
# $Id: pkginstall.sh,v 1.19 2007/01/16 10:14:46 rionda Exp $

set -e -u

if [ -z "${LOGFILE:-}" ]; then
    echo "This script can't run standalone."
    echo "Please use launch.sh to execute it."
    exit 1
fi

#$BASE_DIR/tools/builder_scripts/packages

PFSPKGFILE=/tmp/pfspackages

if [ ! -f ${PFSPKGFILE} ]; then
    return
fi

if [ "${ARCH}" != "$(uname -p)" ]; then
    echo "----------------------------------------------------------"
    echo "You can install packages only if your machine architecture"
    echo "is the same of the target architecture."
    echo "----------------------------------------------------------"
    echo "Skipping package installation."
    sleep 5
    return    
fi

WORKDIR=$(mktemp -d -t freesbie)
CHROOTWD=$(TMPDIR=${BASEDIR}/tmp mktemp -d -t freesbie)

escape_pkg() {
    echo $1 | sed 's/\+/\\\+/'
}

find_origins() {
    cd ${WORKDIR}
    touch origins
    echo -n ">>> Finding origins... "
    while read row; do
	if [ -z "${row}" ]; then continue; fi
	set +e
	if (echo ${row} | grep -q "^#"); then continue; fi 
	set -e

	pkg=$(echo $row | cut -d\  -f 1)

	# pkg_info might fail if the listed package isn't present
	set +e
	origins=$(pkg_info -EX "^$(escape_pkg ${pkg})($|-[^-]+$)")
	retval=$?
	set -e
	if [ ${retval} -eq 0 ]; then
	    # Valid origin(s) found
	    for origin in ${origins}; do
		echo ${origin} >> tmp_origins
	    done
	else
	    echo
	    echo "Warning! Package \"${pkg}\" is listed"
	    echo "in ${PFSPKGFILE},"
	    echo "but is not present in your system. "
	    echo "Press CTRL-C in ten seconds if you want"
	    echo "to stop now or I'll continue anyway"
	    sleep 10
	fi
    done < ${PFSPKGFILE}
    if [ -f tmp_origins ]; then
	sort -u tmp_origins > origins
	tot=$(wc -l origins | awk '{print $1}')
	echo "${tot} found"
    else
	echo "none found"
    fi
}

find_deps() {
    cd ${WORKDIR}
    touch deps
    echo -n ">>> Finding dependencies... "
    while read pkg; do
	deps=$(pkg_info -qr ${pkg} | cut -d ' ' -f 2)
	for dep in ${deps}; do
	    echo ${dep} >> tmp_deps
	done      
	
	
    done < origins
    if [ -f tmp_deps ]; then
	sort -u tmp_deps > deps
	tot=$(wc -l deps | awk '{print $1}')
	echo "${tot} found"
    else
	echo "none found"
    fi
}

sort_packages() {
    cd ${WORKDIR}
    pkgfile=${WORKDIR}/packages
    presortfile=${WORKDIR}/presortpkg
    sortfile=${WORKDIR}/sortpkg
    sort -u deps origins > $pkgfile

    [ -f $sortfile ] && rm $sortfile 
    touch $sortfile

    count() {
        file=$1;
        echo $(wc -l ${file} | awk '{print $1}')
    }

    totpkg=$(wc -l $pkgfile | awk '{print $1}')
    echo -n ">>> Sorting ${totpkg} packages by dependencies... "

    touch $presortfile
    for i in $(cat $pkgfile); do
	if [ -e /var/db/pkg/$i/+REQUIRED_BY ]; then	    
	    for j in $(cat /var/db/pkg/$i/+REQUIRED_BY); do
		if grep -q ^${j}\$ $pkgfile; then
		    echo $i $j >> $presortfile
		else
		    echo $i NULL >> $presortfile
		fi
	    done
	else
            echo $i NULL >> $presortfile
	fi
    done
    
    tsort $presortfile | grep -v '^NULL$' > $sortfile

    echo "done."
}

copy_packages() {
    export PACKAGE_BUILDING=yo
    chrootpkgpath=${CHROOTWD#$BASEDIR}
    pkgfile=${WORKDIR}/sortpkg
    pkgaddcmd="chroot ${BASEDIR} pkg_add -fv"
    totpkg=$(wc -l $pkgfile | awk '{print $1}')
    echo ">>> Copying ${totpkg} packages"
    cd ${CHROOTWD}
    set +e
    echo -n "[0"
    count=1
    while read pkg; do
	# Progress bar
	if [ $((${count} % 10)) -eq 0 ]; then
	    echo -n ${count}
	else
	    echo -n "."
	fi
	count=$((${count} + 1))

	echo ">>> Running pkg_create -b ${pkg} ${CHROOTWD}/${pkg}.tar" >> ${LOGFILE}
	pkg_create -b ${pkg} ${CHROOTWD}/${pkg}.tar >> ${LOGFILE} 2>&1

	echo ">>> Running $pkgaddcmd ${chrootpkgpath}/${pkg}.tar" >> ${LOGFILE}
	$pkgaddcmd ${chrootpkgpath}/${pkg}.tar >> ${LOGFILE} 2>&1

	rm ${CHROOTWD}/${pkg}.tar

    done < $pkgfile
    echo "]"
    set -e
}

delete_old_packages() {
    echo ">>> Deleting previously installed packages"
    chroot ${BASEDIR} pkg_delete -a >> ${LOGFILE} 2>&1
}

# Deletes workdirs
purge_wd() {
    cd ${LOCALDIR}
    rm -rf ${WORKDIR} ${BASEDIR}/tmp/freesbie*
}

trap "purge_wd && exit 1" INT

echo ">>> Installing packages listed in ${PFSPKGFILE}"
find_origins

if [ "$(wc -l ${WORKDIR}/origins | awk '{print $1}')" = "0" ]; then
    # Empty packages file, skip.
    purge_wd
    return
fi

find_deps
sort_packages
#delete_old_packages
copy_packages
purge_wd
