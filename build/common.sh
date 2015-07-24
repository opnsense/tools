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

SCRUB_ARGS=:

usage()
{
	echo "Usage: ${0} -f flavour -n name -v version -R freebsd-ports.git" >&2
	echo "	-C core.git -P ports.git -S src.git -T tools.git" >&2
	exit 1
}

while getopts C:f:n:P:p:R:S:s:T:v: OPT; do
	case ${OPT} in
	C)
		export COREDIR=${OPTARG}
		SCRUB_ARGS=${SCRUB_ARGS};shift;shift
		;;
	f)
		export PRODUCT_FLAVOUR=${OPTARG}
		SCRUB_ARGS=${SCRUB_ARGS};shift;shift
		;;
	n)
		export PRODUCT_NAME=${OPTARG}
		SCRUB_ARGS=${SCRUB_ARGS};shift;shift
		;;
	P)
		export PORTSDIR=${OPTARG}
		SCRUB_ARGS=${SCRUB_ARGS};shift;shift
		;;
	p)
		export PLUGINSDIR=${OPTARG}
		SCRUB_ARGS=${SCRUB_ARGS};shift;shift
		;;
	R)
		export PORTSREFDIR=${OPTARG}
		SCRUB_ARGS=${SCRUB_ARGS};shift;shift
		;;
	S)
		export SRCDIR=${OPTARG}
		SCRUB_ARGS=${SCRUB_ARGS};shift;shift
		;;
	s)
		export PRODUCT_SETTINGS=${OPTARG}
		SCRUB_ARGS=${SCRUB_ARGS};shift;shift
		;;
	T)
		export TOOLSDIR=${OPTARG}
		SCRUB_ARGS=${SCRUB_ARGS};shift;shift
		;;
	v)
		export PRODUCT_VERSION=${OPTARG}
		SCRUB_ARGS=${SCRUB_ARGS};shift;shift
		;;
	*)
		usage
		;;
	esac
done

if [ -z "${PRODUCT_NAME}" -o \
    -z "${PRODUCT_FLAVOUR}" -o \
    -z "${PRODUCT_VERSION}" -o \
    -z "${PRODUCT_SETTINGS}" -o \
    -z "${TOOLSDIR}" -o \
    -z "${PLUGINSDIR}" -o \
    -z "${PORTSDIR}" -o \
    -z "${PORTSREFDIR}" -o \
    -z "${COREDIR}" -o \
    -z "${SRCDIR}" ]; then
	usage
fi

# full name for easy use and actual config directory
export PRODUCT_RELEASE="${PRODUCT_NAME}-${PRODUCT_VERSION}-${PRODUCT_FLAVOUR}"

# misc. foo
export CONFIG_PKG="/usr/local/etc/pkg/repos/origin.conf"
export CPUS=$(sysctl kern.smp.cpus | awk '{ print $2 }')
export CONFIG_XML="/usr/local/etc/config.xml"
export ARCH=${ARCH:-$(uname -m)}
export LABEL=${PRODUCT_NAME}
export TARGET_ARCH=${ARCH}
export TARGETARCH=${ARCH}

# define target directories
export CONFIGDIR="${TOOLSDIR}/config/${PRODUCT_SETTINGS}"
export STAGEDIR="/usr/local/stage"
export IMAGESDIR="/tmp/images"
export SETSDIR="/tmp/sets"
export PACKAGESDIR="/.pkg"

# bootstrap target directories
mkdir -p ${STAGEDIR} ${IMAGESDIR} ${SETSDIR}

# target files
export CDROM="${IMAGESDIR}/${PRODUCT_RELEASE}-cdrom-${ARCH}.iso"
export SERIALIMG="${IMAGESDIR}/${PRODUCT_RELEASE}-serial-${ARCH}.img"
export VGAIMG="${IMAGESDIR}/${PRODUCT_RELEASE}-vga-${ARCH}.img"
export NANOIMG="${IMAGESDIR}/${PRODUCT_RELEASE}-nano-${ARCH}.img"

# print environment to showcase all of our variables
env | sort

git_checkout()
{
	git -C ${1} clean -xdqf .
	REPO_TAG=${2}
	if [ -z "${REPO_TAG}" ]; then
		git_tag ${1} ${PRODUCT_VERSION}
	fi
	git -C ${1} reset --hard ${REPO_TAG}
}

git_update()
{
	git -C ${1} fetch --all --prune
	if [ -n "${2}" ]; then
		git_checkout ${1} ${2}
	fi
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

git_tag()
{
	# Fuzzy-match a tag and return it for the caller.

	POOL=$(git -C ${1} tag | grep ^${2}\$ || true)
	if [ -z "${POOL}" ]; then
		VERSION=${2%.*}
		FUZZY=${2##${VERSION}.}

		for _POOL in $(git -C ${1} tag | grep ^${VERSION} | sort -r); do
			_POOL=${_POOL##${VERSION}}
			if [ -z "${_POOL}" ]; then
				POOL=${VERSION}${_POOL}
				break
			fi
			if [ ${_POOL##.} -lt ${FUZZY} ]; then
				POOL=${VERSION}${_POOL}
				break
			fi
		done
	fi

	if [ -z "${POOL}" ]; then
		echo ">>> ${1} doesn't match tag ${2}"
		exit 1
	fi

	echo ">>> ${1} matches tag ${2} -> ${POOL}"

	export REPO_TAG=${POOL}
}

setup_clone()
{
	echo ">>> Setting up ${2} clone in ${1}"

	# repositories may be huge so avoid the copy :)
	mkdir -p ${1}${2} && mount_unionfs -o below ${2} ${1}${2}
}

setup_copy()
{
	echo ">>> Setting up ${2} copy in ${1}"

	# in case we want to clobber HEAD
	git clone ${2} ${1}${2}
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
	local MARKER="/usr/local/opnsense/version/os-update.${3}"

	if [ ! -f ${1}${MARKER} ]; then
		# first call means bootstrap the marker file
		mkdir -p ${1}$(dirname ${MARKER})
		echo ${2} > ${1}${MARKER}
	fi
}

setup_base()
{
	local BASE_SET BASE_VER

	echo ">>> Setting up world in ${1}"

	BASE_SET=$(find ${SETSDIR} -name "base-*-${ARCH}.txz")

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

	setup_marker ${1} ${BASE_VER%%.txz} base
}

setup_kernel()
{
	local KERNEL_SET KERNEL_VER

	echo ">>> Setting up kernel in ${1}"

	KERNEL_SET=$(find ${SETSDIR} -name "kernel-*-${ARCH}.txz")

	tar -C ${1} -xpf ${KERNEL_SET}

	KERNEL_VER=${KERNEL_SET##${SETSDIR}/kernel-}

	setup_marker ${1} ${KERNEL_VER%%.txz} kernel
}

extract_packages()
{
	echo ">>> Extracting packages in ${1}"

	BASEDIR=${1}

	rm -rf ${BASEDIR}${PACKAGESDIR}/All
	mkdir -p ${BASEDIR}${PACKAGESDIR}/All

	PACKAGESET=$(find ${SETSDIR} -name "packages-*-${PRODUCT_FLAVOUR}-${ARCH}.tar")
	if [ -f "${PACKAGESET}" ]; then
		tar -C ${BASEDIR}${PACKAGESDIR} -xpf ${PACKAGESET}
	fi
}

remove_packages()
{
	echo ">>> Removing packages in ${1}"

	BASEDIR=${1}
	shift
	PKGLIST=${@}

	for PKG in ${PKGLIST}; do
		# clear out the ports that ought to be rebuilt
		for PKGFILE in $({
			cd ${BASEDIR}
			find .${PACKAGESDIR}/All -type f
		}); do
			PKGINFO=$(pkg -c ${BASEDIR} info -F ${PKGFILE} | grep ^Name | awk '{ print $3; }')
			if [ ${PKG} = ${PKGINFO} ]; then
				rm ${PKGFILE}
			fi
		done
	done
}

install_packages()
{
	echo ">>> Installing packages in ${1}..."

	BASEDIR=${1}
	shift
	PKGLIST=${@}

	# remove previous packages for a clean environment
	pkg -c ${BASEDIR} remove -fya

	if [ -z "${PKGLIST}" ]; then
		for PKG in $({
			cd ${BASEDIR}
			find .${PACKAGESDIR}/All -type f
		}); do
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
			PKGFOUND=
			for PKGFILE in $({
				cd ${BASEDIR}
				find .${PACKAGESDIR}/All -name "${PKG}-*.txz"
			}); do
				PKGINFO=$(pkg -c ${BASEDIR} info -F ${PKGFILE} | grep ^Name | awk '{ print $3; }')
				if [ ${PKG} = ${PKGINFO} ]; then
					PKGFOUND=${PKGFILE}
				fi
			done
			pkg -c ${BASEDIR} add ${PKGFOUND}
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

custom_packages()
{
	chroot ${1} /bin/sh -es << EOF
# clear the internal staging area and package files
rm -rf ${1}

# run the package build process
make -C ${2} DESTDIR=${1} FLAVOUR=${PRODUCT_FLAVOUR} install
make -C ${2} DESTDIR=${1} scripts
make -C ${2} DESTDIR=${1} manifest > ${1}/+MANIFEST
make -C ${2} DESTDIR=${1} plist > ${1}/plist

echo -n ">>> Creating custom package for \$(make -C ${2} name)... "
pkg create -m ${1} -r ${1} -p ${1}/plist -o ${PACKAGESDIR}/All
echo "done"
EOF
}

bundle_packages()
{
	sh ./clean.sh packages

	git_describe ${PORTSDIR}

	# rebuild expected FreeBSD structure
	mkdir -p ${1}${PACKAGESDIR}-new/Latest
	mkdir -p ${1}${PACKAGESDIR}-new/All

	# push packages to home location
	cp ${1}${PACKAGESDIR}/All/* ${1}${PACKAGESDIR}-new/All

	# needed bootstrap glue when no packages are on the system
	(cd ${1}${PACKAGESDIR}-new/Latest; ln -s ../All/pkg-*.txz pkg.txz)

	local SIGNARGS=
	if [ -n "$(${TOOLSDIR}/scripts/pkg_fingerprint.sh)" ]; then
		# XXX check if fingerprint is in core.git
		SIGNARGS="signing_command: ${TOOLSDIR}/scripts/pkg_sign.sh"
	fi

	# generate index files
	pkg repo ${1}${PACKAGESDIR}-new/ ${SIGNARGS}

	REPO_RELEASE="${REPO_VERSION}-${PRODUCT_FLAVOUR}-${ARCH}"
	echo -n ">>> Creating package mirror set for ${REPO_RELEASE}... "
	tar -C ${STAGEDIR}${PACKAGESDIR}-new -cf \
	    ${SETSDIR}/packages-${REPO_RELEASE}.tar .
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

	local MOUNTDIRS="/dev ${SRCDIR} ${PORTSDIR} ${COREDIR} ${PLUGINSDIR}"

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
