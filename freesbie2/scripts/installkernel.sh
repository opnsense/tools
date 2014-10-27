#!/bin/sh
#
# Copyright (c) 2005 Dario Freni
#
# See COPYING for licence terms.
#
# $FreeBSD$
# $Id: installkernel.sh,v 1.10 2008/11/03 04:17:14 sullrich Exp $

set -e -u

if [ -z "${LOGFILE:-}" ]; then
    echo "This script can't run standalone."
    echo "Please use launch.sh to execute it."
    sleep 999
    exit 1
fi

# Set SRC_CONF variable if it's not already set.
if [ -z "${SRC_CONF:-}" ]; then
    if [ -n "${MINIMAL:-}" ]; then
		SRC_CONF=${LOCALDIR}/conf/make.conf.minimal
    else
		SRC_CONF=${LOCALDIR}/conf/make.conf.${FREEBSD_VERSION}
    fi
fi

# Set __MAKE_CONF variable if it's not already set.
if [ -z "${MAKE_CONF:-}" ]; then
        MAKE_CONF=""
else
        MAKE_CONF="__MAKE_CONF=$MAKE_CONF"
        echo ">>> Setting MAKE_CONF to $MAKE_CONF"
fi

if [ -n "${KERNELCONF:-}" ]; then
    export KERNCONFDIR=$(dirname ${KERNELCONF})
    export KERNCONF=$(basename ${KERNELCONF})
elif [ -z "${KERNCONF:-}" ]; then
    export KERNCONFDIR=${LOCALDIR}/conf/${ARCH}
    export KERNCONF="FREESBIE"
fi

mkdir -p ${BASEDIR}/boot
#cp ${SRCDIR}/sys/${ARCH}/conf/GENERIC.hints ${BASEDIR}/boot/device.hints
#echo hint.psm.0.flags=0x1000 >> ${BASEDIR}/boot/device.hints
 
cd ${SRCDIR}

if [ -z "${WITH_DTRACE:-}" ]; then
	DTRACE=""
else
	DTRACE=" WITH_CTF=1"
fi

makeargs="${MAKEOPT:-} ${MAKEJ_KERNEL:-} ${MAKE_CONF} SRCCONF=${SRC_CONF} TARGET_ARCH=${ARCH} DESTDIR=${KERNEL_DESTDIR}"

echo ">>> FreeSBIe2 is running the command: env $MAKE_ENV script -aq $LOGFILE make ${makeargs:-} installkernel ${DTRACE}"  > ${BUILDER_LOGS}/freesbie2/freesbie_installkernel_cmd.txt

(env "$MAKE_ENV" script -aq $LOGFILE make ${makeargs:-} installkernel || print_error;) | egrep '^>>>'

gzip -f9 $KERNEL_DESTDIR/boot/kernel/kernel

cd $LOCALDIR


