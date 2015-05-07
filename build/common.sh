#!/bin/sh

# Copyright (c) 2014-2015 Franco Fichtner <franco@opnsense.org>
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

# important build settings
export PRODUCT_VERSION=${PRODUCT_VERSION:-"`date '+%Y%m%d%H%M'`"}
export PRODUCT_FLAVOUR=${PRODUCT_FLAVOUR:-"OpenSSL"}
export PRODUCT_NAME="OPNsense"

# full name for easy use
export PRODUCT_RELEASE="${PRODUCT_NAME}-${PRODUCT_VERSION}_${PRODUCT_FLAVOUR}"

# code reositories
export TOOLSDIR="/usr/tools"
export PORTSDIR="/usr/ports"
export COREDIR="/usr/core"
export SRCDIR="/usr/src"

# misc. foo
export CONFIG_PKG="/usr/local/etc/pkg/repos/${PRODUCT_NAME}.conf"
export CPUS=`sysctl kern.smp.cpus | awk '{ print $2 }'`
export CONFIG_XML="/usr/local/etc/config.xml"
export ARCH=${ARCH:-"`uname -m`"}
export LABEL=${PRODUCT_NAME}
export TARGET_ARCH=${ARCH}
export TARGETARCH=${ARCH}

# define target directories
export PACKAGESDIR="/tmp/packages/${ARCH}/${PRODUCT_FLAVOUR}"
export STAGEDIR="/usr/local/stage"
export IMAGESDIR="/tmp/images"
export SETSDIR="/tmp/sets"

# bootstrap target directories
mkdir -p ${STAGEDIR} ${PACKAGESDIR} ${IMAGESDIR} ${SETSDIR}

# target files
export CDROM="${IMAGESDIR}/${PRODUCT_RELEASE}-cdrom-${ARCH}.iso"
export SERIALIMG="${IMAGESDIR}/${PRODUCT_RELEASE}-serial-${ARCH}.img"
export VGAIMG="${IMAGESDIR}/${PRODUCT_RELEASE}-vga-${ARCH}.img"
export NANOIMG="${IMAGESDIR}/${PRODUCT_RELEASE}-nano-${ARCH}.img"

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

	git -C ${1} reset --hard HEAD
	git -C ${1} clean -xdqf .
}

git_describe()
{
	VERSION=$(git -C ${1} describe --abbrev=0)
	REVISION=$(git -C ${1} rev-list ${VERSION}.. --count)
	COMMENT=$(git -C ${1} rev-list HEAD --max-count=1 | cut -c1-9)
	if [ "${REVISION}" != "0" ]; then
		# must construct full version string manually
		VERSION=${VERSION}_${REVISION}
	fi

	export REPO_VERSION=${VERSION}
	export REPO_COMMENT=${COMMENT}
}

setup_clone()
{
	echo ">>> Setting up ${2} in ${1}"

	# repositories may be huge so avoid the copy :)
	mkdir -p ${1}${2} && mount_unionfs -o below ${2} ${1}${2}
}

setup_chroot()
{
	echo ">>> Setting up chroot in ${1}"

	cp /etc/resolv.conf ${1}/etc
	mount -t devfs devfs ${1}/dev
	chroot ${1} /etc/rc.d/ldconfig start
}

setup_marker()
{
	# Let opnsense-update(8) know it's up to date
	local MARKER="/usr/local/opnsense/version/os-update"

	if [ ! -f ${1}${MARKER} ]; then
		# first call means bootstrap the marker file
		mkdir -p ${1}$(dirname ${MARKER})
		echo ${2} > ${1}${MARKER}
	else
		# subsequent call means make sure version matches
		# (base and kernel must be in sync at all times)
		if [ $(cat ${1}${MARKER}) != ${2} ]; then
			echo "base/kernel version mismatch"
			exit 1
		fi
	fi
}

setup_base()
{
	local BASE_SET BASE_VER

	echo ">>> Setting up world in ${1}"

	BASE_SET=$(ls ${SETSDIR}/base-*-${ARCH}.txz)

	tar -C ${1} -xpf ${BASE_SET}

	# setup vt(4) consistently
	cat > ${1}/boot/loader.conf << EOF
kern.vty="vt"
EOF

	# /home is needed for LiveCD images, and since it
	# belongs to the base system, we create it from here.
	mkdir -p ${1}/home

	# /conf is needed for the config subsystem at this
	# point as the storage location.  We ought to add
	# this here, because otherwise read-only install
	# media wouldn't be able to bootstrap the directory.
	mkdir -p ${1}/conf

	BASE_VER=${BASE_SET##${SETSDIR}/base-}

	setup_marker ${1} ${BASE_VER%%.txz}
}

setup_kernel()
{
	local KERNEL_SET KERNEL_VER
	echo ">>> Setting up kernel in ${1}"

	KERNEL_SET=$(ls ${SETSDIR}/kernel-*-${ARCH}.txz)

	tar -C ${1} -xpf ${KERNEL_SET}

	KERNEL_VER=${KERNEL_SET##${SETSDIR}/kernel-}

	setup_marker ${1} ${KERNEL_VER%%.txz}
}

setup_packages()
{
	echo ">>> Setting up packages in ${1}..."

	BASEDIR=${1}
	shift
	PKGLIST=${@}

	mkdir -p ${BASEDIR}${PACKAGESDIR}
	tar -C ${PACKAGESDIR} -cf - . | \
	    tar -C ${BASEDIR}${PACKAGESDIR} -xpf -

	if [ -z "${PKGLIST}" ]; then
		PKGLIST=$(ls ${PACKAGESDIR}/*.txz || true)
		for PKG in ${PKGLIST}; do
			# Adds all available packages but ignores the
			# ones that cannot be installed due to missing
			# dependencies.  This behaviour is desired.
			pkg -c ${BASEDIR} add ${PKG} || true
		done
	else
		# always bootstrap pkg as the first package
		for PKG in pkg ${PKGLIST}; do
			# Adds all selected packages and fails if
			# one cannot be installed.  Used to build
			# final images or regression test systems.
			pkg -c ${BASEDIR} add ${PACKAGESDIR}/${PKG}-*.txz
		done
	fi

	# collect all installed packages
	PKGLIST="$(pkg -c ${BASEDIR} query %n)"

	for PKG in ${PKGLIST}; do
		# add, unlike install, is not aware of repositories :(
		pkg -c ${BASEDIR} annotate -qyA ${PKG} \
		    repository ${PRODUCT_NAME}
	done

	# keep the directory!
	rm -rf ${BASEDIR}${PACKAGESDIR}/*
}

setup_mtree()
{
	echo ">>> Creating mtree summary of files present..."

	cat > ${1}/tmp/installed_filesystem.mtree.exclude <<EOF
./dev
./tmp
EOF
	chroot ${1} /bin/sh -es <<EOF
/usr/sbin/mtree -c -k uid,gid,mode,size,sha256digest -p / -X /tmp/installed_filesystem.mtree.exclude > /tmp/installed_filesystem.mtree
/bin/chmod 600 /tmp/installed_filesystem.mtree
/bin/mv /tmp/installed_filesystem.mtree /etc/
/bin/rm /tmp/installed_filesystem.mtree.exclude
EOF
}

setup_stage()
{
	echo ">>> Setting up stage in ${1}"

	local MOUNTDIRS="/dev /usr/src /usr/ports /usr/core"

	# might have been a chroot
	for DIR in ${MOUNTDIRS}; do
		if [ -d ${1}${DIR} ]; then
			umount ${1}${DIR} 2> /dev/null || true
		fi
	done

	# remove base system files
	rm -rf ${1} 2> /dev/null ||
	    (chflags -R noschg ${1}; rm -rf ${1} 2> /dev/null)

	# revive directory for next run
	mkdir -p ${1}
}
