#!/bin/sh
#
# Copyright (c) 2005 Dario Freni
#
# See COPYING for licence terms.
#
# $FreeBSD$
# $Id: extra.sh,v 1.1.1.1 2008/03/25 19:58:16 sullrich Exp $

set -e -u

if [ -z "${LOGFILE:-}" ]; then
    echo "This script can't run standalone."
    echo "Please use launch.sh to execute it."
    exit 1
fi

if [ -z "${EXTRAPLUGINS:-}" ]; then
    # No plugins selected, return with no errors
    return
fi

echo -n ">>> Running plugins:"

for plugin in ${EXTRAPLUGINS}; do
    echo -n " ${plugin}"
    if [ -f "${LOCALDIR}/extra/${ARCH}/${plugin}.sh" ]; then
		. ${LOCALDIR}/extra/${ARCH}/${plugin}.sh
    elif [ -f "${LOCALDIR}/extra/${plugin}.sh" ]; then
		. ${LOCALDIR}/extra/${plugin}.sh
    else
		#
    fi
done

echo " Done!"
