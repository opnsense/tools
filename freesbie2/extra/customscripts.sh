#!/bin/sh
#
# Copyright (c) 2005 Dominique Goncalves
#
# See COPYING for licence terms.
#
# $FreeBSD$
# $Id: customscripts.sh,v 1.1.1.1 2008/03/25 19:58:15 sullrich Exp $

set -e -u

if [ -z "${LOGFILE:-}" ]; then
    echo "This script can't run standalone."
    echo "Please use launch.sh to execute it."
    exit 1
fi

CUSTOMSCRIPTS=${CUSTOMSCRIPTS:-extra/customscripts}

cd ${CUSTOMSCRIPTS}
for script in `find . -type f -name "*.sh"` ; do
        /bin/cp ${script} ${BASEDIR}/root
        echo -n "  ${script}"
        /usr/sbin/chroot ${BASEDIR} /bin/sh /root/${script}
        /bin/rm ${BASEDIR}/root/${script}
done

cd ${LOCALDIR}
