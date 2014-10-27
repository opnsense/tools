#!/bin/sh
# 
# Copyright (c) 2002-2004 G.U.F.I.
# Copyright (c) 2005 Matteo Riondato & Dario Freni
#
# See COPYING for licence terms-
#
# $Id: xkbdlayout.sh,v 1.1.1.1 2008/03/25 19:58:16 sullrich Exp $
#
# X keyboard selection script

X11_ETCPATH=/etc/X11
LOCKFILE=${X11_ETCPATH}/.xkbdsel.keep
X_CFG=${X11_ETCPATH}/xorg.conf

if [ ! -f /usr/X11R6/bin/X -o ! -f ${X_CFG} ]; then
    exit
fi

if [ ! -e ${LOCKFILE} ]; then
    touch ${LOCKFILE}
else
    exit
fi

# Create Xkbd Layout Dialog
DIALOG_FILE=$BASEDIR/usr/local/share/xconfig/xkbddialog.sh
LAYOUT_DIR="/usr/X11R6/lib/X11/xkb/rules/"
if [ -e $LAYOUT_DIR/xorg.lst ]; then
    LAYOUT_FILE=$LAYOUT_DIR/xorg.lst
else
    exit 1
fi

TMPFILE=$(mktemp -t xorg.lst)

awk 'BEGIN{ORS=" "}{
  if ($1 == "!") {
    if ($2 == "layout") {
      getline;
        while ($0 != "!" && $0 != "") {
          print $1 " \"" $2 "\"";
          getline;
      }
    }
  }
}' $LAYOUT_FILE > $TMPFILE


ARG=$(cat $TMPFILE)
CMD='dialog --title "FreeSBIE X.org Layout" \
    --menu "Choose your preferred keyboard layout" 22 50 15 \
    '${ARG}'2> '$TMPFILE


set +e
# Running dialog, overwriting TMPFILE
eval "$CMD" 
retval=$?
set -e

if [ $retval = 1 ]; then
    echo "Canceled"
    rm ${LOCKFILE}
    exit 1
fi

LAYOUT=$(cat $TMPFILE)

#Re use the TMPFILE
cp ${X_CFG} ${TMPFILE}
sed "s/\"us\"/\"${LAYOUT}\"/" ${TMPFILE} > ${X_CFG}

rm ${TMPFILE}

