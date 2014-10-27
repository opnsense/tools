#!/bin/sh
#
# Copyright (c) 2005 Dario Freni
#
# See COPYING for licence terms.
#
# $FreeBSD$
# $Id: buildmodules.sh,v 1.1.1.1 2008/03/25 19:58:15 sullrich Exp $
#
# Build modules listed in BUILDMODULES variable. Useful in minimal
# environments when NO_MODULES is set.

set -e -u

if [ -z "${LOGFILE:-}" ]; then
    echo "This script can't run standalone."
    echo "Please use launch.sh to execute it."
    exit 1
fi

BUILDMODULES=${BUILDMODULES:-}

makecmd="make __SRCCONF=${SRC_CONF} SRCCONF=${SRC_CONF} TARGET_ARCH=${ARCH} DESTDIR=${BASEDIR}"

set +e # grep could fail.
for i in ${BUILDMODULES} ; do
	(cd ${SRCDIR}/sys/modules/${i}/ && \
	  ${makecmd} clean && \
	  ${makecmd} depend && \
	  ${makecmd} all && \
	  ${makecmd} install DESTDIR=${BASEDIR} && \
	  ${makecmd} clean) | grep '^====>'
done

return 0
