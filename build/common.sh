#!/bin/sh

# Copyright (c) 2014-2016 Franco Fichtner <franco@opnsense.org>
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
	echo "	-C core.git -P ports.git -S src.git -T tools.git -t type" >&2
	echo "	-k /path/to/privkey -K /path/to/pubkey -m web_mirror" >&2
	echo "  [ -l customsigncheck -L customsigncommand ]" >&2
	echo "  [ -o stagedirprefix ] [...]" >&2
	exit 1
}

while getopts C:f:K:k:L:l:m:n:o:P:p:R:S:s:T:t:v: OPT; do
	case ${OPT} in
	C)
		export COREDIR=${OPTARG}
		SCRUB_ARGS=${SCRUB_ARGS};shift;shift
		;;
	f)
		export PRODUCT_FLAVOUR=${OPTARG}
		SCRUB_ARGS=${SCRUB_ARGS};shift;shift
		;;
	K)
		export PRODUCT_PUBKEY=${OPTARG}
		SCRUB_ARGS=${SCRUB_ARGS};shift;shift
		;;
	k)
		export PRODUCT_PRIVKEY=${OPTARG}
		SCRUB_ARGS=${SCRUB_ARGS};shift;shift
		;;
	L)
		if [ -n "${OPTARG}" ]; then
			export PRODUCT_SIGNCMD=${OPTARG}
		fi
		SCRUB_ARGS=${SCRUB_ARGS};shift;shift
		;;
	l)
		if [ -n "${OPTARG}" ]; then
			export PRODUCT_SIGNCHK=${OPTARG}
		fi
		SCRUB_ARGS=${SCRUB_ARGS};shift;shift
		;;
	m)
		export PRODUCT_MIRROR=${OPTARG}
		SCRUB_ARGS=${SCRUB_ARGS};shift;shift
		;;
	n)
		export PRODUCT_NAME=${OPTARG}
		SCRUB_ARGS=${SCRUB_ARGS};shift;shift
		;;
	o)
		if [ -n "${OPTARG}" ]; then
			export STAGEDIRPREFIX=${OPTARG}
		fi
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
	t)
		export PRODUCT_TYPE=${OPTARG}
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
    -z "${PRODUCT_TYPE}" -o \
    -z "${PRODUCT_FLAVOUR}" -o \
    -z "${PRODUCT_VERSION}" -o \
    -z "${PRODUCT_SETTINGS}" -o \
    -z "${PRODUCT_MIRROR}" -o \
    -z "${PRODUCT_PRIVKEY}" -o \
    -z "${PRODUCT_PUBKEY}" -o \
    -z "${TOOLSDIR}" -o \
    -z "${PLUGINSDIR}" -o \
    -z "${PORTSDIR}" -o \
    -z "${PORTSREFDIR}" -o \
    -z "${COREDIR}" -o \
    -z "${SRCDIR}" ]; then
	usage
fi

# automatically expanded product stuff
export PRODUCT_SIGNCMD=${PRODUCT_SIGNCMD:-"${TOOLSDIR}/scripts/pkg_sign.sh ${PRODUCT_PUBKEY} ${PRODUCT_PRIVKEY}"}
export PRODUCT_SIGNCHK=${PRODUCT_SIGNCHK:-"${TOOLSDIR}/scripts/pkg_fingerprint.sh ${PRODUCT_PUBKEY}"}
export PRODUCT_RELEASE="${PRODUCT_NAME}-${PRODUCT_VERSION}-${PRODUCT_FLAVOUR}"

# serial bootstrapping
SERIAL_CONFIG="<enableserial>1</enableserial>"
SERIAL_CONFIG="${SERIAL_CONFIG}<serialspeed>${SERIAL_SPEED}</serialspeed>"
export SERIAL_CONFIG="${SERIAL_CONFIG}<primaryconsole>serial</primaryconsole>"
export SERIAL_SPEED="115200"

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
export STAGEDIR="${STAGEDIRPREFIX}${CONFIGDIR}/${PRODUCT_FLAVOUR}"
export IMAGESDIR="/tmp/images"
export SETSDIR="/tmp/sets"
export PACKAGESDIR="/.pkg"

# bootstrap target directories
mkdir -p ${STAGEDIR} ${IMAGESDIR} ${SETSDIR}

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
	HEAD=${2:-"HEAD"}

	VERSION=$(git -C ${1} describe --abbrev=0 --always ${HEAD})
	REVISION=$(git -C ${1} rev-list --count ${VERSION}..${HEAD})
	COMMENT=$(git -C ${1} rev-list --max-count=1 ${HEAD} | cut -c1-9)
	REFTYPE=$(git -C ${1} cat-file -t ${HEAD})

	if [ "${REVISION}" != "0" ]; then
		# must construct full version string manually
		VERSION=${VERSION}_${REVISION}
	fi

	export REPO_VERSION=${VERSION}
	export REPO_COMMENT=${COMMENT}
	export REPO_REFTYPE=${REFTYPE}
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
	rm -rf ${1}${2}
	mkdir -p $(dirname ${1}${2})
	cp -r ${2} ${1}${2}
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
	local MARKER="/usr/local/opnsense/version/opnsense-update.${3}"

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

setup_distfiles()
{
	echo ">>> Setting up distfiles in ${1}"

	DISTFILES_SET=$(find ${SETSDIR} -name "distfiles-*.tar")
	if [ -n "${DISTFILES_SET}" ]; then
		mkdir -p ${1}${PORTSDIR}
		tar -C ${1}${PORTSDIR} -xpf ${DISTFILES_SET}
	fi
}

setup_entropy()
{
	echo ">>> Setting up entropy in ${1}"

	mkdir -p ${1}/boot

	umask 077

	dd if=/dev/random of=${1}/boot/entropy bs=4096 count=1
	dd if=/dev/random of=${1}/entropy bs=4096 count=1

	chown 0:0 ${1}/boot/entropy
	chown 0:0 ${1}/entropy

	umask 022
}

generate_signature()
{
	if [ -n "$(${PRODUCT_SIGNCHK})" ]; then
		echo -n "Signing $(basename ${1})... "
		sha256 -q ${1} | ${PRODUCT_SIGNCMD} > ${1}.sig
		echo "done"
	fi
}

check_packages()
{
	PACKAGESET=$(find ${SETSDIR} -name "packages-*-${PRODUCT_FLAVOUR}-${ARCH}.tar")
	MARKER=${1}
	SKIP=${2}

	if [ -z "${MARKER}" -o -z "${PACKAGESET}" -o -n "${SKIP}" ]; then
		return
	fi

	DONE=$(tar tf ${PACKAGESET} | grep "^\./\.${MARKER}_done\$" || true)
	if [ -n "${DONE}" ]; then
		echo ">>> Packages (${MARKER}) are up to date"
		exit 0
	fi
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
	BASEDIR=${1}
	shift
	PKGLIST=${@}

	echo ">>> Removing packages in ${BASEDIR}: ${PKGLIST}"

	for PKG in ${PKGLIST}; do
		# clear out the ports that ought to be rebuilt
		for PKGFILE in $(cd ${BASEDIR}${PACKAGESDIR}; find All -type f); do
			PKGINFO=$(pkg -c ${BASEDIR} info -F ${PACKAGESDIR}/${PKGFILE} | grep ^Name | awk '{ print $3; }')
			if [ ${PKG} = ${PKGINFO} ]; then
				rm ${BASEDIR}${PACKAGESDIR}/${PKGFILE}
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
			# find all package files, omitting plugins
			find .${PACKAGESDIR}/All -type f \! -name "os-*"
		}); do
			# Adds all available packages and removes the
			# ones that cannot be installed due to missing
			# dependencies.  This behaviour is desired.
			if ! pkg -c ${BASEDIR} add ${PKG}; then
				rm -r ${BASEDIR}/${PKG}
			fi
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
			if [ -n "${PKGFOUND}" ]; then
				pkg -c ${BASEDIR} add ${PKGFOUND}
			else
				echo "Could not find package: ${PKG}" >&2
				exit 1
			fi
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
make -C ${2} DESTDIR=${1} ${3} FLAVOUR=${PRODUCT_FLAVOUR} install
make -C ${2} DESTDIR=${1} ${3} scripts
make -C ${2} DESTDIR=${1} ${3} manifest > ${1}/+MANIFEST
make -C ${2} DESTDIR=${1} ${3} plist > ${1}/plist

echo -n ">>> Creating custom package for ${2}... "
pkg create -m ${1} -r ${1} -p ${1}/plist -o ${PACKAGESDIR}/All
echo "done"
EOF
}

bundle_packages()
{
	BASEDIR=${1}
	MARKER=${2}

	sh ./clean.sh packages

	git_describe ${PORTSDIR}

	# rebuild expected FreeBSD structure
	mkdir -p ${BASEDIR}${PACKAGESDIR}-new/Latest
	mkdir -p ${BASEDIR}${PACKAGESDIR}-new/All

	for PROGRESS in $({
		find ${BASEDIR}${PACKAGESDIR} -type f -name ".*_done"
	}); do
		# push previous markers to home location
		cp ${PROGRESS} ${BASEDIR}${PACKAGESDIR}-new
	done

	if [ -n "${MARKER}" ]; then
		# add build marker to set
		touch ${BASEDIR}${PACKAGESDIR}-new/.${MARKER}_done
	fi

	# push packages to home location
	cp ${BASEDIR}${PACKAGESDIR}/All/* ${BASEDIR}${PACKAGESDIR}-new/All

	# needed bootstrap glue when no packages are on the system
	(cd ${BASEDIR}${PACKAGESDIR}-new/Latest; ln -s ../All/pkg-*.txz pkg.txz)

	SIGNARGS=

	if [ -n "$(${PRODUCT_SIGNCHK})" ]; then
		SIGNARGS="signing_command: ${PRODUCT_SIGNCMD}"
	fi

	# generate pkg bootstrap signature
	generate_signature ${BASEDIR}${PACKAGESDIR}-new/Latest/pkg.txz

	# generate index files
	pkg repo ${BASEDIR}${PACKAGESDIR}-new/ ${SIGNARGS}

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
	install_packages ${@} ${PRODUCT_TYPE}
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
