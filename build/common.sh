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

BUILD_CONF=../config/build.conf

# load previous settings
if [ -f ${BUILD_CONF} ]; then
	. ${BUILD_CONF}
fi

# important build settings
export PRODUCT_VERSION=${PRODUCT_VERSION:-$(date '+%Y%m%d%H%M')}
export PRODUCT_FLAVOUR=${PRODUCT_FLAVOUR:-"OpenSSL"}
export PRODUCT_NAME=${PRODUCT_NAME:-"OPNsense"}

# full name for easy use
export PRODUCT_RELEASE="${PRODUCT_NAME}-${PRODUCT_VERSION}_${PRODUCT_FLAVOUR}"

# code reositories
export TOOLSDIR="/usr/tools"
export PORTSDIR="/usr/ports"
export COREDIR="/usr/core"
export SRCDIR="/usr/src"

# misc. foo
export CONFIG_PKG="/usr/local/etc/pkg/repos/${PRODUCT_NAME}.conf"
export PRODUCT_CONFIG="${TOOLSDIR}/config/${PRODUCT_NAME}"
export CPUS=$(sysctl kern.smp.cpus | awk '{ print $2 }')
export CONFIG_XML="/usr/local/etc/config.xml"
export ARCH=${ARCH:-$(uname -m)}
export LABEL=${PRODUCT_NAME}
export TARGET_ARCH=${ARCH}
export TARGETARCH=${ARCH}

# define target directories
export PACKAGESDIR="/packages"
export STAGEDIR="/usr/local/stage"
export IMAGESDIR="/tmp/images"
export SETSDIR="/tmp/sets"

# bootstrap target directories
mkdir -p ${STAGEDIR} ${IMAGESDIR} ${SETSDIR}

# target files
export CDROM="${IMAGESDIR}/${PRODUCT_RELEASE}-cdrom-${ARCH}.iso"
export SERIALIMG="${IMAGESDIR}/${PRODUCT_RELEASE}-serial-${ARCH}.img"
export VGAIMG="${IMAGESDIR}/${PRODUCT_RELEASE}-vga-${ARCH}.img"
export NANOIMG="${IMAGESDIR}/${PRODUCT_RELEASE}-nano-${ARCH}.img"

# print environment to showcase all of our variables
env | sort

setup_env()
{
	rm -f ${BUILD_CONF}

	# these variables are allowed to steer the build
	[ -n "${1}" ] && echo "export PRODUCT_NAME=${1}" >> ${BUILD_CONF}
	[ -n "${2}" ] && echo "export PRODUCT_FLAVOUR=${2}" >> ${BUILD_CONF}
	[ -n "${3}" ] && echo "export PRODUCT_VERSION=${3}" >> ${BUILD_CONF}
}

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
	VERSION=$(git -C ${1} describe --abbrev=0 --always)
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

extract_packages()
{
	echo ">>> Extracting packages in ${1}"

	BASEDIR=${1}
	shift
	PKGLIST=${@}

	rm -rf ${BASEDIR}${PACKAGESDIR}/All
	mkdir -p ${BASEDIR}${PACKAGESDIR}/All

	PACKAGESET=$(ls ${SETSDIR}/packages-*_${PRODUCT_FLAVOUR}-${ARCH}.tar || true)
	if [ -f "${PACKAGESET}" ]; then
		tar -C ${BASEDIR}${PACKAGESDIR} -xpf ${PACKAGESET}
	fi

	if [ -n "${PKGLIST}" ]; then
		for PKG in ${PKGLIST}; do
			# clear out the ports that ought to be rebuilt
			rm -f ${BASEDIR}${PACKAGESDIR}/All/${PKG}-*.txz
		done
	fi
}

install_packages()
{
	echo ">>> Installing packages in ${1}..."

	BASEDIR=${1}
	shift
	PKGLIST=${@}

	if [ -z "${PKGLIST}" ]; then
		PKGLIST=$(cd ${BASEDIR}${PACKAGESDIR}/All; ls *.txz || true)
		for PKG in ${PKGLIST}; do
			# Adds all available packages but ignores the
			# ones that cannot be installed due to missing
			# dependencies.  This behaviour is desired.
			pkg -c ${BASEDIR} add ${PACKAGESDIR}/All/${PKG} || true
		done
	else
		# always bootstrap pkg as the first package
		for PKG in pkg ${PKGLIST}; do
			# Adds all selected packages and fails if
			# one cannot be installed.  Used to build
			# final images or regression test systems.
			PKG=$(chroot ${BASEDIR} /bin/sh -ec "cd ${PACKAGESDIR}/All; ls ${PKG}-*.txz" | head -n1)
			pkg -c ${BASEDIR} add ${PACKAGESDIR}/All/${PKG}
		done
	fi

	# collect all installed packages
	PKGLIST="$(pkg -c ${BASEDIR} query %n)"

	for PKG in ${PKGLIST}; do
		# add, unlike install, is not aware of repositories :(
		pkg -c ${BASEDIR} annotate -qyA ${PKG} \
		    repository ${PRODUCT_NAME}
	done
}

bundle_packages()
{
	rm -f ${SETSDIR}/packages-*_${PRODUCT_FLAVOUR}-${ARCH}.tar

	# rebuild expected FreeBSD structure
	mkdir -p ${1}/pkg-repo/Latest
	mkdir -p ${1}/pkg-repo/All

	# push packages to home location
	cp ${1}${PACKAGESDIR}/All/* ${1}/pkg-repo/All

	# needed bootstrap glue when no packages are on the system
	(cd ${1}/pkg-repo/Latest; ln -s ../All/pkg-*.txz pkg.txz)

	local SIGNARGS=
	if [ -n "$(${TOOLSDIR}/scripts/pkg_fingerprint.sh)" ]; then
		# XXX check if fingerprint is in core.git
		SIGNARGS="signing_command: ${TOOLSDIR}/scripts/pkg_sign.sh"
	fi

	# generate index files
	pkg repo ${1}/pkg-repo ${SIGNARGS}

	echo -n ">>> Creating package mirror set for ${PRODUCT_RELEASE}... "

	tar -C ${STAGEDIR}/pkg-repo -cf \
	    ${SETSDIR}/packages-${PRODUCT_VERSION}_${PRODUCT_FLAVOUR}-${ARCH}.tar .

	echo "done"
}

clean_packages()
{
	rm -rf ${1}${PACKAGESDIR}
}

setup_packages()
{
	# legacy package extract
	extract_packages ${1}
	install_packages ${@}
	clean_packages ${1}
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
