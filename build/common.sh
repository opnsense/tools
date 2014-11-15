#!/bin/sh

# Copyright (c) 2014 Franco Fichtner <franco@lastsummer.de>
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

set -e

# build directories
export STAGEDIR="/usr/local/stage"
export PACKAGESDIR="/tmp/packages"
export IMAGESDIR="/tmp/images"
export SETSDIR="/tmp/sets"

# target files
export ISOPATH="${IMAGESDIR}/LiveCD.iso"

# code reositories
export TOOLSDIR="/usr/tools"
export PORTSDIR="/usr/ports"
export COREDIR="/usr/core"
export SRCDIR="/usr/src"

# misc. foo
export CPUS=`sysctl kern.smp.cpus | awk '{ print $2 }'`

# print environment to showcase all of our variables
env

git_clear()
{
	# Reset the git repository into a known state by
	# enforcing a hard-reset to HEAD (so you keep your
	# selected commit, but no manual changes) and all
	# unknown files are cleared (so it looks like a
	# freshly cloned repository).

	echo -n ">>> Resetting ${1}... "

	# set used here to avoid errors when git isn't bootstrapped
	set +e
	git -C ${1} reset --hard HEAD
	git -C ${1} clean -xdqf .
	set -e
}

setup_base()
{
	echo ">>> Setting up world in ${1}"

	# XXX The installer is hardwired to copy
	# /home and will bail if it can't be found!
	mkdir -p ${1}/home

	(cd ${1} && tar -Jxpf ${SETSDIR}/base.txz)
}

setup_kernel()
{
	echo ">>> Setting up kernel in ${1}"

	(cd ${1} && tar -Jxpf ${SETSDIR}/kernel.txz)
}

setup_packages()
{
	echo ">>> Setting up packages in ${1}..."

	ASSUME_ALWAYS_YES=yes pkg bootstrap

	mkdir -p ${1}/${PACKAGESDIR}
	cp ${PACKAGESDIR}/* ${1}/${PACKAGESDIR}

	# XXX upstream for for -f is in pkg 1.4 onwards
	pkg -c ${1} add -f ${PACKAGESDIR}/*.txz

	rm -r ${1}/${PACKAGESDIR}
}

setup_platform()
{
	git_clear ${COREDIR}

	echo ">>> Setting up core in ${1}..."

	# XXX horribe stuff follows...
	cp ${TOOLSDIR}/freesbie2/extra/varmfs/varmfs.rc ${1}/etc/rc.d/varmfs
	cp ${TOOLSDIR}/freesbie2/extra/etcmfs/etcmfs.rc ${1}/etc/rc.d/etcmfs
	rm -rf ${1}/usr/sbin/pc-sysinstall
	cd ${COREDIR} && cp -r * ${1}
	mkdir ${1}/conf
}

setup_stage()
{
	rm -rf "${1}" 2>/dev/null ||
	    (chflags -R noschg "${1}"; rm -rf "${1}" 2>/dev/null)
	mkdir -p "${1}"
}
