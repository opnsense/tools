#!/bin/sh
#
# Copyright (c) 2005 Dario Freni
#
# See COPYING for licence terms.
#
# $FreeBSD$
# $Id: pkgselect.sh,v 1.1.1.1 2008/03/25 19:58:16 sullrich Exp $

set -e -u

if [ -z "${LOGFILE:-}" ]; then
    echo "This script can't run standalone."
    echo "Please use launch.sh to execute it."
    exit 1
fi

WORKDIR=$(mktemp -d -t freesbie)
PFSPFSPKGFILE=${PFSPFSPKGFILE:-${LOCALDIR}/packages};

# Check if there are packages installed on the system
check_pkgs() {
    count=$(pkg_info -Qoa | wc -l)
    if [ ${count} -eq 0 ]; then
	/usr/bin/dialog --title "FreeSBIE Packages selection" --clear \
	--msgbox "Sorry, you don't have any packages installed.\n\nPlease install at least the packages you want\nto include in your distribution." 10 50
	exit
    fi
}

escape_pkg() {
    echo $1 | sed 's/\+/\\\+/'                                         
}

create_lists() {
    cd ${WORKDIR}
    echo "Creating list of available packages on the build machine..."

    # Create a different file for each category. Each row in each file
    # will look like:
    # PKGNAME PKGNAME-version    
    pkg_info -Qoa | awk \
' BEGIN { FS=":|/" } 
{ 
    a=$1;
    gsub("-[^-]+$", "", a); 
    system("echo " $1 " >> " $2 ".src");
}
';

    CATEGORIES=$(basename -s '.src' *.src)

    # If PFSPKGFILE already exists, find the listed packages and write
    # them down in the proper category selection files
    if [ -f ${PFSPKGFILE} ]; then

	echo "Using ${PFSPKGFILE} as source..."

	while read row; do
	    if [ -z ${row} ]; then continue; fi
	    pkg=$(echo $row | cut -d\  -f 1)

	    # pkg_info might fail if the listed package isn't present
	    set +e
	    origins=$(pkg_info -QoX "^$(escape_pkg ${pkg})($|-[^-]+$)")
	    retval=$?
	    set -e
	    if [ ${retval} -eq 0 ]; then
		# Valid origin(s) found
		for origin in ${origins}; do
		    echo ${origin} | awk \
' BEGIN { FS=":|/" } 
{ 
    system("echo " $1 " >> " $2 ".sel");
}
';
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
    fi
}

category_dialog() {
    CATEGORY=$1;
    ARG=""

    cd ${WORKDIR}
    if [ -f ${CATEGORY}.src ]; then
	while read i;
	do
	  # If a file with previous selections exists check whether
	  # this package is selected or not
	  status="off"
	  if [ -f ${CATEGORY}.sel ]; then
	      # grep might exit with error
	      set +e
	      grep -qE "^${i}($|-[^-]+$)" ${CATEGORY}.sel;
	      retval=$?
	      set -e
	      if [ ${retval} -eq 0 ]; then
		  status="on";
	      fi
	  fi
	  ARG="${ARG} ${i} \"\" ${status}"
	done < ${CATEGORY}.src
    fi

    # Construct the dialog command line
    CMD='/usr/bin/dialog --title "FreeSBIE Packages selection" --clear \
    --checklist \
    "These are the available packages under the '${CATEGORY}' category" \
    -1 -1 10 '${ARG}' 2> '${CATEGORY}.tmp
    # Disabling -e flag because dialog can exit with values different
    # than zero.
    set +e
    # Running dialog
    eval "$CMD" 
    retval=$?
    set -e
    case ${retval} in
	0)
	    # Put the list of selected packages in ${CATEGORY}.sel, one per row
	    rm -f ${CATEGORY}.sel
	    pkglist=$(cat ${CATEGORY}.tmp)
	    if [ -n "${pkglist}" ]; then
		for pkg in ${pkglist}; do
		    eval "echo ${pkg} >> ${CATEGORY}.sel"
		done
	    fi
	    ;;
	*)
	    # Abnormal exit, don't do anything
	    ;;
    esac

    main_dialog
}

main_dialog() {
    ARG=""
    for i in $CATEGORIES;
      do
      ARG="${ARG} ${i} \"\""
    done
    
    # Construct the dialog command line
    CMD='/usr/bin/dialog --title "FreeSBIE Packages selection" --clear \
    --menu "These are the available packages on your system \n \
    Choose packages to include in FreeSBIE" -1 -1 10 \
    "save and exit" "" " " "" '${ARG}' 2> '${WORKDIR}/cat_choice

    # Disabling -e flag because dialog can exit with values different
    # than zero.
    set +e
    # Running dialog
    eval "$CMD"
    retval=$?
    set -e
    case ${retval} in
	0)
	    choice=$(cat ${WORKDIR}/cat_choice)
	    case ${choice} in
		save*and*exit)
		    collect_save
		    ;;
		*)
		    if [ -z ${choice} ]; then
			# The empty row case
			main_dialog
		    else
			category_dialog ${choice}
		    fi
		    ;;
	    esac
	    ;;
	*)
	    echo "Exiting without saving"
	    ;;
    esac
    
}

collect_save() {
    cd ${WORKDIR}
    # Ugly way to find if *.sel is expanded to a list of files
    for i in *.sel; do
      if [ -f ${i} ]; then
	  # There's at least one .sel file
	  sort *.sel > ${PFSPKGFILE}
	  echo "List of packages saved on ${PFSPKGFILE}"
      else
	  echo "No packages selected, removing ${PFSPKGFILE}"
	  rm ${PFSPKGFILE}
      fi
      # No iterations required
      break;
    done
}

# Deletes workdir
purge_wd() {
    cd ${LOCALDIR}
    rm -rf ${WORKDIR}
}

trap "purge_wd && exit 1" INT

check_pkgs
create_lists
main_dialog
purge_wd
