#!/bin/sh
#
# Copyright (c) 2006 Matteo Riondato
#
# See COPYING for licence terms.
#
# $FreeBSD$
# $Id: l10n.sh,v 1.1.1.1 2008/03/25 19:58:15 sullrich Exp $

set -e -u

if [ -z "${LOGFILE:-}" ]; then
    echo "This script can't run standalone."
    echo "Please use launch.sh to execute it."
    exit 1
fi

cp ${LOCALDIR}/extra/l10n/l10n.rc ${BASEDIR}/etc/rc.d/l10n
chmod 555 ${BASEDIR}/etc/rc.d/l10n
