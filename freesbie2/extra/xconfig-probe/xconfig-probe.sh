#!/bin/sh

# Copyright (c) 2005 Timothy Redaelli
#
# See COPYING for licence terms.
#
# $Id: xconfig-probe.sh,v 1.1.1.1 2008/03/25 19:58:16 sullrich Exp $
#
# Video Card Detection script

if [ ! -x /usr/X11R6/bin/X ]; then
	exit
fi

echo "Creating xorg.conf..."
PATH_DEST=/etc/X11
PATH_ORIG=/usr/local/share/xconfig

X_CFG_ORIG=${PATH_ORIG}/xorg.conf.orig
X_CFG_AUTO=/root/xorg.conf.new
X_CFG=${PATH_DEST}/xorg.conf

if [ -f "${X_CFG}" ]; then
	echo "xorg.conf found... skipping"
	exit
fi

cp "${X_CFG_ORIG}" "${X_CFG}"

if /usr/X11R6/bin/X -configure; then
	awk '/^Section "Device"/,/^EndSection/' "${X_CFG_ORIG}" >> "${X_CFG}"
	rm -f "${X_CFG_ORIG}"
else
	printf 'Section "Device"\n\tIdentifier  "Card0"\n\tDriver      "vesa"\nEndSection\n' >> "${X_CFG}"
fi
