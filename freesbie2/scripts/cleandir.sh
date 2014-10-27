#!/bin/sh
#
# Copyright (c) 2005 Dario Freni
#
# See COPYING for licence terms.
#
# $FreeBSD$
# $Id: cleandir.sh,v 1.3 2008/11/09 07:00:32 sullrich Exp $

set +e -u

if [ -z "${LOGFILE:-}" ]; then
    echo "This script can't run standalone."
    echo "Please use launch.sh to execute it."
    exit 1
fi

echo -n ">>> Removing build directories"

if [ -d "${BASEDIR}" ]; then
	BASENAME=`basename ${BASEDIR}`
	echo -n "$BASENAME "
    chflags -R noschg ${BASEDIR}
    rm -rf ${BASEDIR} 2>/dev/null
fi

if [ -d "${CLONEDIR}" ]; then
	BASENAME=`basename ${CLONEDIR}`
	echo -n "$BASENAME "
    chflags -R noschg ${CLONEDIR}
    rm -rf ${CLONEDIR} 2>/dev/null
fi

set -e -u

echo "Done!"
