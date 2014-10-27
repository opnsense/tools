#!/bin/sh
#
# pfSense specific buildworld.sh
#
# Copyright (c) 2009 Scott Ullrich
# Copyright (c) 2005 Dario Freni
#
# See COPYING for licence terms (HINT: BSD License)
#

set -e -u

if [ -z "${LOGFILE:-}" ]; then
    echo "This script can't run standalone."
    echo "Please use launch.sh to execute it."
    sleep 999
    exit 1
fi

if [ -n "${NO_BUILDWORLD:-}" ]; then
    echo "+++ NO_BUILDWORLD set, skipping build" | tee -a ${LOGFILE}
    return
fi

# Set SRC_CONF variable if it's not already set.
if [ -z "${SRC_CONF:-}" ]; then
    if [ -n "${MINIMAL:-}" ]; then
		SRC_CONF=${LOCALDIR}/conf/make.conf.minimal
    else
		SRC_CONF=${LOCALDIR}/conf/make.conf
    fi
fi
echo ">>> Setting SRC_CONF to $SRC_CONF" | tee -a ${LOGFILE}

# Set __MAKE_CONF variable if it's not already set.
if [ -z "${MAKE_CONF:-}" ]; then
	MAKE_CONF=""
else
	MAKE_CONF="__MAKE_CONF=$MAKE_CONF"
	echo ">>> Setting MAKE_CONF to $MAKE_CONF" | tee -a ${LOGFILE}
fi

cd $SRCDIR

unset EXTRA

makeargs="${MAKEOPT:-} ${MAKEJ_WORLD:-} ${MAKE_CONF} SRCCONF=${SRC_CONF} TARGET=${ARCH} TARGET_ARCH=${ARCH}"

if [ "$ARCH" = "mips" ]; then
	echo ">>> Building includes for ${ARCH} architecture..." | tee -a ${LOGFILE}
	make buildincludes 2>&1 >/dev/null
	echo ">>> Installing includes for ${ARCH} architecture..." | tee -a ${LOGFILE}
	make installincludes 2>&1 >/dev/null
fi

echo ">>> Building world for ${ARCH} architecture..." | tee -a ${LOGFILE}
echo ">>> FreeSBIe2 is running the command: env $MAKE_ENV script -aq $LOGFILE make ${makeargs:-} buildworld" | tee -a ${LOGFILE}
make buildincludes 2>&1 >/dev/null
make installincludes 2>&1 >/dev/null
(env "$MAKE_ENV" script -aq $LOGFILE make ${makeargs:-} buildworld || print_error;) | egrep '^>>>' | tee -a ${LOGFILE}

cd $LOCALDIR
