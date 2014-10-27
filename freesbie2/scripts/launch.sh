#!/bin/sh
#
# Wrapper to include configuration variables and invoke correct scripts
#
# Copyright (c) 2005 Dario Freni
#
# See COPYING for license terms.
#
# $FreeBSD$
# $Id: launch.sh,v 1.8 2008/12/30 23:24:09 smos Exp $
#
# Usage: launch.sh ${TARGET} [ ${LOGFILE} ]

set -e -u

if [ "`id -u`" != "0" ]; then
    echo "Sorry, this must be done as root."
    sleep 999
    exit 1
fi

# If the FREESBIE_DEBUG environment variable is set, be verbose.
[ ! -z "${FREESBIE_DEBUG:-}" ] && set -x

# Set the absolute path for the toolkit dir
LOCALDIR=$(cd $(dirname $0)/.. && pwd)

CURDIR=$1;
shift;

TARGET=$1;
shift;

# Set LOGFILE. If it's a tmp file, schedule for deletion
if [ -z "${LOGFILE:-}" ]; then
	if [ -n "${1:-}" ]; then
    		LOGFILE=$1
    		REMOVELOG=0
	else
    		LOGFILE=$(mktemp -q /tmp/freesbie.XXXXXX)
    		REMOVELOG=1
	fi
else
	REMOVELOG=0
fi

echo ">>> LOGFILE set to $LOGFILE. REMOVELOG is $REMOVELOG." | tee -a ${LOGFILE}
cd $CURDIR

. ./conf/freesbie.defaults.conf

FREESBIE_CONF=${FREESBIE_CONF:-./conf/freesbie.conf}

[ -f ${FREESBIE_CONF} ] && . ${FREESBIE_CONF}

# XXX set $ARCH and mandatory variables here.

if [ ! -z "${ARCH:-}" ]; then
	ARCH=${ARCH:-`uname -p`}
fi

# Some variables can be passed to make only as environment, not as parameters.
# usage: env $MAKE_ENV make $makeargs
MAKE_ENV=${MAKE_ENV:-}

if [ -n ${MAKEOBJDIRPREFIX:-} ]; then
    MAKE_ENV="$MAKE_ENV MAKEOBJDIRPREFIX=${MAKEOBJDIRPREFIX}"
fi

if [ -n ${MAKEOBJDIR:-} ]; then
    MAKE_ENV="$MAKE_ENV MAKEOBJDIR=${MAKEOBJDIR}"
fi

echo ">>> MAKE_ENV set on launch.sh to $MAKE_ENV" | tee -a ${LOGFILE}

report_error() {
    if [ ! -z ${FREESBIE_ERROR_MAIL:-} ]; then
	HOSTNAME=`hostname`
	IPADDRESS=`ifconfig | grep inet | grep netmask | grep broadcast | awk '{ print $2 }'`
	cat ${LOGFILE} | \
	    mail -s "FreeSBIE (pfSense) build error in ${TARGET} phase ${IPADDRESS} - ${HOSTNAME} " \
	    ${FREESBIE_ERROR_MAIL}
    fi
}

print_error() {
    echo "Something went wrong, check errors!" >&2
    [ -n "${LOGFILE:-}" ] && \
	echo "Log saved on ${LOGFILE}" >&2
    report_error
    tail -n20 ${LOGFILE} >&2
    sleep 999
    kill $$ # XXX exit 1 won't work.
}

# If SCRIPTS_OVERRIDE is not defined, set it to ${LOCALDIR}/scripts/custom
SCRIPTS_OVERRIDE=${SCRIPTS_OVERRIDE:-"${LOCALDIR}/scripts/custom"}

# Check order:
#  - ${SCRIPTS_OVERRIDE}/${ARCH}/${TARGET}.sh
#  - ${SCRIPTS_OVERRIDE}/${TARGET}.sh
#  - scripts/${ARCH}/${TARGET}.sh
#  - scripts/${TARGET}.sh

if [ -f "${SCRIPTS_OVERRIDE}/${ARCH}/${TARGET}.sh" ]; then
    . ${SCRIPTS_OVERRIDE}/${ARCH}/${TARGET}.sh
elif [ -f "${SCRIPTS_OVERRIDE}/${TARGET}.sh" ]; then
    . ${SCRIPTS_OVERRIDE}/${TARGET}.sh
elif [ -f "${LOCALDIR}/scripts/${ARCH}/${TARGET}.sh" ]; then
    . ${LOCALDIR}/scripts/${ARCH}/${TARGET}.sh
elif [ -f "${LOCALDIR}/scripts/${TARGET}.sh" ]; then
    . ${LOCALDIR}/scripts/${TARGET}.sh
fi

[ $? -ne 0 ] && report_error

if [ ${REMOVELOG} -eq 1 ]; then
    rm -f ${LOGFILE}
fi
