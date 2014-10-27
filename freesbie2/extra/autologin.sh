#!/bin/sh
#
# Copyright (c) 2006 Matteo Riondato
#
# See COPYING for licence terms.
#
# $FreeBSD$
# $Id: autologin.sh,v 1.1.1.1 2008/03/25 19:58:15 sullrich Exp $
#
# Enable autologin of the $FREESBIE_ADDUSER user on the first terminal
#

FREESBIE_ADDUSER="${FREESBIE_ADDUSER:-freesbie}"

echo "# ${FREESBIE_ADDUSER} user autologin" >> ${BASEDIR}/etc/gettytab
echo "${FREESBIE_ADDUSER}:\\" >> ${BASEDIR}/etc/gettytab
echo ":al=${FREESBIE_ADDUSER}:ht:np:sp#115200:" >> ${BASEDIR}/etc/gettytab

sed -i "" "/ttyv0/s/Pc/${FREESBIE_ADDUSER}/" ${BASEDIR}/etc/ttys

