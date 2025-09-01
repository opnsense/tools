#!/bin/sh

# Copyright (c) 2014-2025 Franco Fichtner <franco@opnsense.org>
# Copyright (c) 2010-2011 Scott Ullrich <sullrich@gmail.com>
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

OPTS="A:a:B:b:C:c:D:d:E:e:F:G:g:H:h:I:J:K:k:L:l:m:n:O:o:P:p:R:r:S:s:T:t:U:u:v:V:"

while getopts ${OPTS} OPT; do
	case ${OPT} in
	A)
		export PORTSREFURL=${OPTARG}
		;;
	a)
		export PRODUCT_TARGET=${OPTARG%%:*}
		export PRODUCT_ARCH=${OPTARG##*:}
		export PRODUCT_HOST=$(uname -p)
		;;
	B)
		export PORTSBRANCH=${OPTARG}
		;;
	b)
		export SRCBRANCH=${OPTARG}
		;;
	C)
		export COREDIR=${OPTARG}
		;;
	c)
		export PRODUCT_COMSPEED=${OPTARG}
		;;
	d)
		export PRODUCT_DEVICE_REAL=${OPTARG}
		export PRODUCT_DEVICE=${OPTARG}
		;;
	D)
		export EXTRABRANCH=${OPTARG}
		;;
	E)
		export COREBRANCH=${OPTARG}
		;;
	e)
		export PLUGINSBRANCH=${OPTARG}
		;;
	F)
		export PRODUCT_KERNEL=${OPTARG}
		;;
	G)
		export PORTSREFBRANCH=${OPTARG}
		;;
	g)
		export TOOLSBRANCH=${OPTARG}
		;;
	H)
		export COREENV=${OPTARG}
		;;
	h)
		export PLUGINSENV=${OPTARG}
		;;
	I)
		export UPLOADDIR=${OPTARG}
		;;
	J)
		export PORTSENV=${OPTARG}
		;;
	K)
		if [ -n "${OPTARG}" ]; then
			export PRODUCT_PUBKEY=${OPTARG}
		fi
		;;
	k)
		if [ -n "${OPTARG}" ]; then
			export PRODUCT_PRIVKEY=${OPTARG}
		fi
		;;
	L)
		if [ -n "${OPTARG}" ]; then
			export PRODUCT_SIGNCMD=${OPTARG}
		fi
		;;
	l)
		if [ -n "${OPTARG}" ]; then
			export PRODUCT_SIGNCHK=${OPTARG}
		fi
		;;
	m)
		export PRODUCT_MIRROR=${OPTARG}
		;;
	n)
		export PRODUCT_NAME=${OPTARG}
		;;
	O)
		export PRODUCT_GITBASE=${OPTARG}
		;;
	o)
		if [ -n "${OPTARG}" ]; then
			export STAGEDIRPREFIX=${OPTARG}
		fi
		;;
	P)
		export PORTSDIR=${OPTARG}
		;;
	p)
		export PLUGINSDIR=${OPTARG}
		;;
	R)
		export PORTSREFDIR=${OPTARG}
		;;
	r)
		export PRODUCT_SERVER=${OPTARG}
		;;
	S)
		export SRCDIR=${OPTARG}
		;;
	s)
		export CONFIGDIR=${OPTARG}
		;;
	T)
		export TOOLSDIR=${OPTARG}
		;;
	t)
		export PRODUCT_TYPE=${OPTARG}
		;;
	U)
		case "${OPTARG}" in
		''|-business|-devel)
			export PRODUCT_SUFFIX=${OPTARG}
			;;
		*)
			echo "SUFFIX '${OPTARG}' is not supported" >&2
			exit 1
			;;
		esac
		;;
	u)
		export PRODUCT_UEFI=${OPTARG}
		;;
	v)
		for _VERSION in ${OPTARG}; do
			eval "export ${_VERSION}"
		done
		;;
	V)
		export PRODUCT_ADDITIONS=${OPTARG}
		;;
	*)
		echo "${0}: Unknown argument '${OPT}'" >&2
		exit 1
		;;
	esac
done

shift $((OPTIND - 1))

CHECK_MISSING="
CONFIGDIR
COREBRANCH
COREDIR
PLUGINSBRANCH
PLUGINSDIR
PORTSBRANCH
PORTSDIR
PORTSREFDIR
PRODUCT_ABI
PRODUCT_ARCH
PRODUCT_COMSPEED
PRODUCT_DEVICE_REAL
PRODUCT_GITBASE
PRODUCT_KERNEL
PRODUCT_LUA
PRODUCT_MIRROR
PRODUCT_NAME
PRODUCT_PERL
PRODUCT_PHP
PRODUCT_PYTHON
PRODUCT_RUBY
PRODUCT_SERVER
PRODUCT_TYPE
PRODUCT_VERSION
SRCBRANCH
SRCDIR
TOOLSBRANCH
TOOLSDIR
"

for MISSING in ${CHECK_MISSING}; do
	if [ -z "$(eval "echo \${${MISSING}}")" ]; then
		echo "${0}: Missing argument ${MISSING}" >&2
		exit 1
	fi
done

# misc. foo
export CPUS=$(sysctl kern.smp.cpus | awk '{ print $2 }')
export CONFIG_XML="/usr/local/etc/config.xml"
export ABI_FILE="/usr/lib/crt1.o"
export ENV_FILTER="env -i USER=${USER} LOGNAME=${LOGNAME} HOME=${HOME} \
SHELL=${SHELL} BLOCKSIZE=${BLOCKSIZE} MAIL=${MAIL} PATH=${PATH} \
TERM=${TERM} HOSTTYPE=${HOSTTYPE} VENDOR=${VENDOR} OSTYPE=${OSTYPE} \
MACHTYPE=${MACHTYPE} PWD=${PWD} GROUP=${GROUP} HOST=${HOST} \
EDITOR=${EDITOR} PAGER=${PAGER} ABI_FILE=${ABI_FILE}"

# define build and config directories
export PRODUCT_SETTINGS="${CONFIGDIR##*/}"
export DEVICEDIR="${TOOLSDIR}/device"
export PACKAGESDIR="/.pkg"

# load device-specific environment
if [ ! -f ${DEVICEDIR}/${PRODUCT_DEVICE_REAL}.conf ]; then
	echo ">>> No configuration found for device ${PRODUCT_DEVICE_REAL}." >&2
	exit 1
fi
. ${DEVICEDIR}/${PRODUCT_DEVICE_REAL}.conf

# get the current version for the selected source repository
SRCREVISION=unknown
if [ -f ${SRCDIR}/sys/conf/newvers.sh ]; then
	eval export SRC$(grep ^REVISION= ${SRCDIR}/sys/conf/newvers.sh)
fi
export SRCABI="FreeBSD:${SRCREVISION%%.*}:${PRODUCT_ARCH}"

# define and bootstrap target directories
export STAGEDIR="${STAGEDIRPREFIX}${CONFIGDIR}/${PRODUCT_ARCH}"
export TARGETDIRPREFIX="/usr/local/opnsense/build"
export TARGETDIR="${TARGETDIRPREFIX}/${PRODUCT_SETTINGS}/${PRODUCT_ARCH}"
export IMAGESDIR="${TARGETDIR}/images"
export LOGSDIR="${TARGETDIR}/logs"
export SETSDIR="${TARGETDIR}/sets"
mkdir -p ${IMAGESDIR} ${SETSDIR} ${LOGSDIR}

# automatically expanded product stuff
export PRODUCT_PRIVKEY=${PRODUCT_PRIVKEY:-"${CONFIGDIR}/repo.key"}
export PRODUCT_PUBKEY=${PRODUCT_PUBKEY:-"${CONFIGDIR}/repo.pub"}
export PRODUCT_SIGNCMD=${PRODUCT_SIGNCMD:-"${TOOLSDIR}/scripts/pkg_sign.sh ${PRODUCT_PUBKEY} ${PRODUCT_PRIVKEY}"}
export PRODUCT_SIGNCHK=${PRODUCT_SIGNCHK:-"${TOOLSDIR}/scripts/pkg_fingerprint.sh ${PRODUCT_PUBKEY}"}
export PRODUCT_RELEASE="${PRODUCT_NAME}${PRODUCT_SUFFIX}-${PRODUCT_VERSION}"
export PRODUCT_CORES="${PRODUCT_TYPE} ${PRODUCT_TYPE}-devel ${PRODUCT_TYPE}-business"
export PRODUCT_CORE="${PRODUCT_TYPE}${PRODUCT_SUFFIX}"
export PRODUCT_DEVEL="${PRODUCT_SUFFIX%-business}"
export PRODUCT_PLUGINS="os-*"
export PRODUCT_PLUGIN="os-*${PRODUCT_DEVEL}"

# assume that arguments mean we are doing a rebuild
if [ -n "${*}" ]; then
	export PRODUCT_REBUILD=yes
fi

case "${SELF}" in
clean|confirm|fingerprint|info|list|make\.conf|print)
	;;
*)
	if [ -z "${PRINT_ENV_SKIP}" ]; then
		export PRINT_ENV_SKIP=1
		env | sort
	fi
	echo ">>> Running build step: ${SELF}"
	echo ">>> Passing arguments: ${*:-"(none)"}"
	;;
esac

for WANT in git pkg; do
	if [ -z "$(which ${WANT})" ]; then
		echo ">>> Required binary '${WANT}' is not installed." >&2
		exit 1
	fi
done

if [ ${PRODUCT_HOST} != ${PRODUCT_ARCH} ]; then
	export PRODUCT_WANTS="${PRODUCT_WANTS} ${PRODUCT_WANTS_CROSS}"
	export MAKE_ARGS_DEV="${MAKE_ARGS_DEV} ${MAKE_ARGS_DEV_CROSS}"
	export PRODUCT_CROSS="yes"
fi

for WANT in ${PRODUCT_WANTS}; do
	if ! pkg info ${WANT} > /dev/null; then
		echo ">>> Required package '${WANT}' is not installed." >&2
		exit 1
	fi
done

git_reset()
{
	if [ ${1} != ${TOOLSDIR} ]; then
		git -C ${1} clean -xdqf .
	fi
	REPO_TAG=${2}
	if [ -z "${REPO_TAG}" ]; then
		git_tag ${1} ${PRODUCT_VERSION}
	fi
	git -C ${1} reset --hard ${REPO_TAG}
}

git_fetch()
{
	echo ">>> Fetching ${1}:"

	# sometimes tagging needs to be redone but a fetch
	# will fail because of clobbered tags so when passing
	# a tag to be stripped try removal to unbreak
	if [ -n "${REPO_STRIP}" ]; then
		git -C ${1} tag -d ${REPO_STRIP} || true
	fi

	git -C ${1} fetch --tags --prune origin
}

git_clone()
{
	if [ -d "${1}/.git" ]; then
		return
	fi

	if [ -d "${1}" ]; then
		echo -n ">>> Resetting ${1}... "
		if ! rm -r "${1}" 2> /dev/null; then
			rm -rf "${1}"/* "${1}"/.??*
		fi
		echo "done"
	else
		mkdir -p $(dirname ${1})
	fi

	echo ">>> Cloning ${1}:"

	URL=${2}

	if [ -z "${URL}" ]; then
		URL=${PRODUCT_GITBASE}/$(basename ${1})
	fi

	git clone --filter=blob:none "${URL}" ${1}
}

git_pull()
{
	echo ">>> Updating branch ${2} of ${1}:"

	git -C ${1} checkout ${2}

	if [ -z "${2%%volatile/*}" ]; then
		git_reset ${1} origin/${2}
	else
		git -C ${1} pull
	fi
}

git_version()
{
	if [ -z "$(echo ${PRODUCT_VERSION} | tr -d 0-9)" ]; then
		git_describe ${1}
		export PRODUCT_VERSION=${REPO_VERSION}
		export PRODUCT_HASH=${REPO_COMMENT}
	fi

	if [ -z "${PRODUCT_VERSION%%*/*}" ]; then
		echo ">>> Invalid product version: ${PRODUCT_VERSION}" >&2
		exit 1
	fi
}

git_describe()
{
	local VERSION=$(git -C ${1} describe --abbrev=0 --always HEAD)
	local REVISION=$(git -C ${1} rev-list --count ${VERSION}..HEAD)
	local COMMENT=$(git -C ${1} rev-list --max-count=1 HEAD | cut -c1-9)
	local BRANCH=$(git -C ${1} rev-parse --abbrev-ref HEAD)

	if [ "${REVISION}" != "0" ]; then
		# must construct full version string manually
		VERSION=${VERSION}_${REVISION}
	fi

	export REPO_BRANCH=${BRANCH}
	export REPO_COMMENT=${COMMENT}
	export REPO_VERSION=${VERSION}
}

git_branch()
{
	# only check for consistency
	if [ -z "${2}" ]; then
		return
	fi

	BRANCH=$(git -C ${1} rev-parse --abbrev-ref HEAD)

	if [ "${2}" != "${BRANCH}" ]; then
		echo ">>> ${1} does not match expected branch: ${2}"
		echo ">>> To continue anyway set ${3}=${BRANCH}"
		exit 1
	fi
}

git_tag()
{
	# Fuzzy-match a tag and return it for the caller.
	local FUZZY
	local MAX
	local VERSION

	POOL=$(git -C ${1} tag | awk '$1 == "'"${2}"'"')
	if [ -z "${POOL}" ]; then
		VERSION=${2%.*}
		FUZZY=${2##${VERSION}.}
		MAX=0

		if [ "$(echo "${VERSION}" | \
		    grep -c '[.]')" = "0" ]; then
			FUZZY=
		fi
	fi

	if [ -z "${POOL}" -a -n "${FUZZY}" ]; then
		for _POOL in $(git -C ${1} tag | \
		    awk 'index($1, "'"${VERSION}"'")'); do
			_POOL=${_POOL##${VERSION}}
			if [ -z "${_POOL}" ]; then
				continue
			fi
			_POOL=${_POOL##.}
			if [ "$(echo "${_POOL}${FUZZY}" | \
			    grep -c '[a-z.]')" != "0" ]; then
				continue
			fi
			if [ ${_POOL} -lt ${FUZZY} -a \
			    ${_POOL} -gt ${MAX} ]; then
				MAX=${_POOL}
				continue
			fi
		done

		if [ ${MAX} -gt 0 ]; then
			POOL=${VERSION}.${MAX}
		else
			POOL=${VERSION}
		fi

		# make sure there is no garbage match
		POOL_TEST=$(git -C ${1} tag | awk '$1 == "'"${POOL}"'"')
		if [ "${POOL_TEST}" != "${POOL}" ]; then
			POOL=
		fi
	fi

	if [ -z "${POOL}" ]; then
		echo ">>> ${1} doesn't match tag ${2}"
		exit 1
	fi

	echo ">>> ${1} matches tag ${POOL}"

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
	cp -R ${2} ${1}${2}
}

setup_xbase()
{
	if [ -z "${PRODUCT_CROSS}" ]; then
		return
	fi

	echo ">>> Cleaning up xtools in ${1}"

	rm -f ${1}/usr/bin/qemu-*-static ${1}/etc/rc.conf.local

	XTOOLSET=$(find_set xtools)
	if [ -z "${XTOOLSET}" ]; then
		return
	fi

	XTOOLS=
	for XTOOL in $(tar tf ${XTOOLSET}); do
		if [ -d ${1}/${XTOOL} ]; then
			continue
		fi
		XTOOLS="${XTOOLS} ${XTOOL}"
	done

	tar -C ${1} -xpf ${SETSDIR}/base-*-${PRODUCT_ARCH}${PRODUCT_DEVICE+"-${PRODUCT_DEVICE}"}.txz ${XTOOLS}
}

setup_xtools()
{
	if [ -z "${PRODUCT_CROSS}" ]; then
		return
	fi

	echo ">>> Setting up xtools in ${1}"

	# additional emulation layer so that chroot
	# looks like a native environment later on
	mkdir -p ${1}/usr/local/bin
	cp /usr/local/bin/qemu-${PRODUCT_ARCH}-static ${1}/usr/local/bin
	/usr/local/etc/rc.d/qemu_user_static onerestart

	# copy the native toolchain for extra speed
	XTOOLSET=$(find_set xtools)
	if [ -n "${XTOOLSET}" ]; then
		tar -C ${1} -xpf ${XTOOLSET}
	fi

	# prevent the start of configd in build environments
	echo 'configd_enable="NO"' >> ${1}/etc/rc.conf.local
}

setup_norun()
{
	# prevent the start of configd
	echo 'configd_enable="NO"' >> ${1}/etc/rc.conf.local

	mount -t devfs devfs ${1}/dev 2> /dev/null || true
}

setup_chroot()
{
	# historic glue
	setup_xtools ${1}
	setup_norun ${1}

	echo ">>> Setting up chroot in ${1}"

	cp /etc/resolv.conf ${1}/etc
	chroot ${1} /bin/sh /etc/rc.d/ldconfig start
}

setup_version()
{
	VERSIONDIR="${2}/usr/local/opnsense/version"

	# clear previous in case of rename
	rm -rf ${VERSIONDIR}

	# estimate size while version dir is gone
	local SIZE=$(tar -C ${2} -c -f - . | wc -c | awk '{ print $1 }')

	# start over
	mkdir -p ${VERSIONDIR}

	# inject obsolete file from previous copy
	if [ -f "${4}" ]; then
		cp ${4} ${VERSIONDIR}/${3}.obsolete
	fi

	# embed size for general information
	echo "${SIZE}" > ${VERSIONDIR}/${3}.size

        # embed commit hash for identification
	echo "${PRODUCT_HASH}" > ${VERSIONDIR}/${3}.hash

	# embed target architecture
	echo "${PRODUCT_ARCH}" > ${VERSIONDIR}/${3}.arch

	# embed version for update checks
	echo "${PRODUCT_VERSION}" > ${VERSIONDIR}/${3}

	# mtree generation must come LAST
	echo "./var" > ${1}/mtree.exclude
	mtree -c -k uid,gid,mode,size,sha256digest -p ${2} \
	    -X ${1}/mtree.exclude > ${1}/mtree
	mv ${1}/mtree ${VERSIONDIR}/${3}.mtree
	rm ${1}/mtree.exclude
	generate_signature ${VERSIONDIR}/${3}.mtree
	chmod 600 ${VERSIONDIR}/${3}.mtree*

	# for testing, custom builds, etc.
	#touch ${VERSIONDIR}/${3}.lock
}

setup_base()
{
	echo ">>> Setting up base in ${1}"

	tar -C ${1} -xpf ${SETSDIR}/base-*-${PRODUCT_ARCH}${PRODUCT_DEVICE+"-${PRODUCT_DEVICE}"}.txz
	rm -f ${1}/.abi_hint

	# /home is needed for LiveCD images, and since it
	# belongs to the base system, we create it from here.
	mkdir -p ${1}/home

	# /conf is needed for the config subsystem at this
	# point as the storage location.  We ought to add
	# this here, because otherwise read-only install
	# media wouldn't be able to bootstrap the directory.
	mkdir -p ${1}/conf
}

setup_kernel()
{
	echo ">>> Setting up kernel in ${1}"

	tar -C ${1} -xpf ${SETSDIR}/kernel-*-${PRODUCT_ARCH}${PRODUCT_DEVICE+"-${PRODUCT_DEVICE}"}.txz
	rm -f ${1}/.abi_hint
}

setup_distfiles()
{
	DSTDIR=${1}
	shift

	echo ">>> Setting up distfiles in ${DSTDIR}"

	DISTFILESET=$(find_set distfiles)
	if [ -n "${DISTFILESET}" ]; then
		mkdir -p ${DSTDIR}${PORTSDIR}
		rm -rf ${DSTDIR}${PORTSDIR}/distfiles
		tar -C ${DSTDIR}${PORTSDIR} -xpf ${DISTFILESET}
	fi

	mkdir -p ${DSTDIR}${PORTSDIR}/distfiles

	if [ -n "${*}" ]; then
		# clear all additional sub-directories passed
		for DIR in ${@}; do
			rm -rf ${DSTDIR}${PORTSDIR}/distfiles/${DIR}
		done

		return 1
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

setup_set()
{
	tar -C ${1} -xJpf ${2}
	rm -f ${1}/.abi_hint
}

generate_set()
{
	echo ">>> Generating set:"

	echo ${SRCABI} > ${1}/.abi_hint
	tar -C ${1} -cvf - . | xz > ${2}
}

generate_signature()
{
	if [ -n "$(${PRODUCT_SIGNCHK})" ]; then
		echo -n ">>> Creating ${PRODUCT_SETTINGS} signature for $(basename ${1})... "
		sha256 -q ${1} | ${PRODUCT_SIGNCMD} > ${1}.sig
		echo "done"
	else
		# do not keep a stale signature
		rm -f ${1}.sig
	fi
}

sign_image()
{
	if [ ! -f "${PRODUCT_PRIVKEY}" ]; then
		return
	fi

	if [ ! -f "${1}".sig ]; then
		echo -n ">>> Creating ${PRODUCT_SETTINGS} signature for $(basename ${1}): "

		openssl dgst -sha256 -sign "${PRODUCT_PRIVKEY}" "${1}" | \
		    openssl base64 > "${1}".sig
	else
		echo -n ">>> Retaining ${PRODUCT_SETTINGS} signature for $(basename ${1}): "
	fi

	openssl base64 -d -in "${1}".sig > "${1}.sig.tmp"
	openssl dgst -sha256 -verify "${PRODUCT_PUBKEY}" \
	    -signature "${1}.sig.tmp" "${1}"
	rm "${1}.sig.tmp"
}

check_image()
{
	local SELF=${1}
	SKIP=${2}

	CHECK=$(find_image "${SELF}")

	if [ -f "${CHECK}" -a -z "${SKIP}" ]; then
		echo ">>> Reusing ${SELF} image: ${CHECK}"
		exit 0
	fi
}

check_packages()
{
	local SELF=${1}
	SKIP=${2}

	PKG_WANT=$(make -C ${PORTSDIR}/ports-mgmt/pkg -v PORTVERSION | cut -d. -f 1-2)
	PKG_HAVE=$(pkg -v | cut -d. -f 1-2)
	if [ "${PKG_WANT}" != "${PKG_HAVE}" ]; then
		echo "Installed pkg version '${PKG_HAVE}' does not match required version '${PKG_WANT}'" >&2
		echo "To fix this please run 'make -C ${PORTSDIR}/ports-mgmt/pkg clean all reinstall'" >&2
		exit 1
	fi

	PACKAGESET=$(find_set packages)

	if [ -z "${SELF}" -o -z "${PACKAGESET}" -o -n "${SKIP}" ]; then
		return 1
	fi

	DONE=$(tar tf ${PACKAGESET} | grep -x "\./\.${SELF}_done" || true)
	if [ -n "${DONE}" ]; then
		return 0
	fi

	return 1
}

find_image()
{
	echo $(find ${IMAGESDIR} -name "*-${1}-${PRODUCT_ARCH}.*" \! -name "*.sig")
}

find_set()
{
	case ${1} in
	base)
		echo $(find ${SETSDIR} -name "base-*-${PRODUCT_ARCH}${PRODUCT_DEVICE+"-${PRODUCT_DEVICE}"}.txz")
		;;
	distfiles)
		echo $(find ${SETSDIR} -name "distfiles-*.tar")
		;;
	kernel-dbg)
		echo $(find ${SETSDIR} -name "kernel-dbg-*-${PRODUCT_ARCH}${PRODUCT_DEVICE+"-${PRODUCT_DEVICE}"}.txz")
		;;
	kernel)
		echo $(find ${SETSDIR} -name "kernel-*-${PRODUCT_ARCH}${PRODUCT_DEVICE+"-${PRODUCT_DEVICE}"}.txz")
		;;
	aux|packages|release)
		echo $(find ${SETSDIR} -name "${1}-*-${PRODUCT_ARCH}.tar")
		;;
	tests|xtools)
		echo $(find ${SETSDIR} -name "${1}-*-${PRODUCT_ARCH}.txz")
		;;
	*)
		echo "Cannot find unknown set: ${1}" >&2
		;;
	esac
}

extract_packages()
{
	echo ">>> Extracting packages in ${1}"

	BASEDIR=${1}

	rm -rf ${BASEDIR}${PACKAGESDIR}/All
	mkdir -p ${BASEDIR}${PACKAGESDIR}/All
	mkdir -p ${BASEDIR}${PACKAGESDIR}/Latest

	PACKAGESET=$(find_set packages)

	if [ -f "${PACKAGESET}" ]; then
		tar -C ${BASEDIR}${PACKAGESDIR} -xpf ${PACKAGESET}
		return 0
	fi

	echo ">>> Extract failed: no packages set found";

	return 1
}

search_packages()
{
	BASEDIR=${1}
	PKGNAME=${2}
	PKGVERS=${3}
	PKGBRCH=${4}

	# check whether the package has already been built
	PKGFILE=${BASEDIR}${PACKAGESDIR}/All/${PKGNAME}-${PKGVERS}.pkg
	if [ -f ${PKGFILE} ]; then
		return 0
	fi

	# check whether the package is available
	# under a different version number
	PKGLINK=${BASEDIR}${PACKAGESDIR}/Latest/${PKGNAME}.pkg
	if [ -L ${PKGLINK} ]; then
		PKGFILE=$(readlink -f ${PKGLINK} || true)
		if [ -f ${PKGFILE} ]; then
			echo ">>> Skipped version ${PKGVERS} for ${PKGNAME} from ${PKGBRCH}" >> ${BASEDIR}/.pkg-msg
			return 0
		fi
	fi

	return 1
}

remove_packages()
{
	BASEDIR=${1}
	shift
	PKGLIST=${@}

	echo ">>> Removing packages in ${BASEDIR}: ${PKGLIST}"

	for PKG in ${PKGLIST}; do
		for PKGFILE in $(cd ${BASEDIR}${PACKAGESDIR}; \
		    find All -name "${PKG}-[0-9]*.pkg" -type f); do
			rm ${BASEDIR}${PACKAGESDIR}/${PKGFILE}
		done
	done
}

prune_packages()
{
	BASEDIR=${1}

	for PKG in $(cd ${1}; find .${PACKAGESDIR}/All -type f); do
		# all packages that install have their dependencies fulfilled
		if pkg -c ${1} add ${PKG}; then
			continue
		fi

		# some packages clash in files with others, check for conflicts
		PKGORIGIN=$(pkg -c ${1} info -F ${PKG} | \
		    grep ^Origin | awk '{ print $3; }')
		PKGGLOBS=
		for CONFLICTS in CONFLICTS CONFLICTS_INSTALL; do
			PKGGLOBS="${PKGGLOBS} $(make -C ${PORTSDIR}/${PKGORIGIN} -v ${CONFLICTS} PHP_DEFAULT=${PRODUCT_PHP})"
		done
		for PKGGLOB in ${PKGGLOBS}; do
			pkg -c ${1} remove -gy "${PKGGLOB}" || true
		done

		# if the conflicts are resolved this works now, but remove
		# the package again as it may clash again later...
		if pkg -c ${1} add ${PKG}; then
			pkg -c ${1} remove -y ${PKGORIGIN}
			continue
		fi

		# if nothing worked, we are missing a dependency and force
		# a rebuild for it and its reverse dependencies later on
		rm -f ${1}/${PKG}

		echo ">>> Unresolvable conflict with package" \
		    "$(basename ${PKG%%.pkg})" >> ${BASEDIR}/.pkg-msg
	done

	pkg -c ${1} set -yaA1
	pkg -c ${1} autoremove -y
}

lock_packages()
{
	BASEDIR=${1}
	shift
	PKGLIST=${@}
	if [ -z "${PKGLIST}" ]; then
		PKGLIST="-a"
	fi

	echo ">>> Locking packages in ${BASEDIR}: ${PKGLIST}"

	for PKG in ${PKGLIST}; do
		pkg -c ${BASEDIR} lock -qy ${PKG}
	done
}

unlock_packages()
{
	BASEDIR=${1}
	shift
	PKGLIST=${@}
	if [ -z "${PKGLIST}" ]; then
		PKGLIST="-a"
	fi

	echo ">>> Unlocking packages in ${BASEDIR}: ${PKGLIST}"

	for PKG in ${PKGLIST}; do
		pkg -c ${BASEDIR} unlock -qy ${PKG}
	done
}

install_packages()
{
	BASEDIR=${1}
	shift
	PKGLIST=${@}

	echo ">>> Installing packages in ${BASEDIR}: ${PKGLIST}"

	# remove previous packages for a clean environment
	pkg -c ${BASEDIR} remove -fya

	# Adds all selected packages and fails if one cannot
	# be installed.  Used to build a runtime environment.
	for PKG in pkg ${PKGLIST}; do
		if [ -n "$(echo "${PKG}" | sed 's/[^*]*//')" ]; then
			echo "Cannot install globbed package: ${PKG}" >&2
			exit 1
		fi
		PKGFOUND=
		for PKGFILE in $({
			cd ${BASEDIR}
			find .${PACKAGESDIR}/All -name ${PKG}-[0-9]*.pkg
		}); do
			pkg -c ${BASEDIR} add ${PKGFILE}
			PKGFOUND=1
		done
		if [ -z "${PKGFOUND}" ]; then
			echo "Could not find package: ${PKG}" >&2
			return 1
		fi
	done

	# collect all installed packages (minus locked packages)
	PKGLIST="$(pkg -c ${BASEDIR} query -e "%k != 1" %n)"

	for PKG in ${PKGLIST}; do
		# add, unlike install, is not aware of repositories :(
		pkg -c ${BASEDIR} annotate -qyA ${PKG} \
		    repository ${PRODUCT_NAME}

		# create the package version file for initial install
		if [ "${PKG}" = "${PRODUCT_CORE}" ]; then
			pkg -c ${BASEDIR} query %v ${PKG} > \
			    ${BASEDIR}/usr/local/opnsense/version/pkgs
		fi
	done
}

custom_packages()
{
	chroot ${1} /bin/sh -es << EOF
make -C ${2} ${3} PKGDIR=${PACKAGESDIR}/All package
EOF

	(
		cd ${1}${PACKAGESDIR}/Latest
		ln -sfn ../All/${4}-${5}.pkg ${4}.pkg
	)

	if [ -n "${PRODUCT_REBUILD}" ]; then
		echo ">>> Rebuilt version ${5} for ${4}" >> ${1}/.pkg-msg
	fi
}

bundle_packages()
{
	BASEDIR=${1}
	SELF=${2}

	shift || true
	shift || true

	REDOS=${@}

	git_version ${PORTSDIR}

	# clean up in case of partial run
	rm -rf ${BASEDIR}${PACKAGESDIR}-new

	# rebuild expected FreeBSD structure
	mkdir -p ${BASEDIR}${PACKAGESDIR}-new/Latest
	mkdir -p ${BASEDIR}${PACKAGESDIR}-new/All

	for PROGRESS in $({
		find ${BASEDIR}${PACKAGESDIR} -type f -name ".*_done"
	}); do
		# push previous markers to home location
		cp ${PROGRESS} ${BASEDIR}${PACKAGESDIR}-new
	done

	for REDO in ${REDOS}; do
		# remove markers we need to rerun
		rm -f ${BASEDIR}${PACKAGESDIR}-new/.${REDO}_done
	done

	if [ -n "${SELF}" -a ! -f ${BASEDIR}/.pkg-err ]; then
		# add build marker to set
		sh ./info.sh > ${BASEDIR}${PACKAGESDIR}-new/.${SELF}_done
	fi

	# push packages to home location
	cp ${BASEDIR}${PACKAGESDIR}/All/* ${BASEDIR}${PACKAGESDIR}-new/All

	SIGNARGS=

	if [ -n "$(${PRODUCT_SIGNCHK})" ]; then
		SIGNARGS="signing_command: ${PRODUCT_SIGNCMD}"
	fi

	# generate all signatures and add bootstrap links
	for PKGFILE in $(cd ${BASEDIR}${PACKAGESDIR}-new; \
	    find All -type f); do
		PKGINFO=$(pkg info -F ${BASEDIR}${PACKAGESDIR}-new/${PKGFILE} \
		    | grep ^Name | awk '{ print $3; }')
		LATESTDIR=${BASEDIR}${PACKAGESDIR}-new/Latest
		ln -sfn ../${PKGFILE} ${LATESTDIR}/${PKGINFO}.pkg
		generate_signature \
		    ${BASEDIR}${PACKAGESDIR}-new/Latest/${PKGINFO}.pkg
	done

	# generate index files (XXX ideally from a chroot)
	pkg repo ${BASEDIR}${PACKAGESDIR}-new/ ${SIGNARGS}

	echo ${SRCABI} > ${BASEDIR}${PACKAGESDIR}-new/.abi_hint

	PACKAGEVER="${PRODUCT_VERSION}-${PRODUCT_ARCH}"
	PACKAGESET="${SETSDIR}/packages-${PACKAGEVER}.tar"
	AUXSET="${SETSDIR}/aux-${PACKAGEVER}.tar"

	if [ -d ${BASEDIR}${PACKAGESDIR}-aux ]; then
		sh ./clean.sh aux

		# generate index files (XXX ideally from a chroot)
		pkg repo ${BASEDIR}${PACKAGESDIR}-aux/ ${SIGNARGS}

		echo ${SRCABI} > ${BASEDIR}${PACKAGESDIR}-aux/.abi_hint

		echo -n ">>> Creating aux package set for ${PACKAGEVER}... "
		tar -C ${BASEDIR}${PACKAGESDIR}-aux -cf ${AUXSET} .
		echo "done"

		generate_signature ${AUXSET}
	fi

	sh ./clean.sh ports

	echo -n ">>> Creating package mirror set for ${PACKAGEVER}... "
	tar -C ${BASEDIR}${PACKAGESDIR}-new -cf ${PACKAGESET} .
	echo "done"

	generate_signature ${PACKAGESET}

	(cd ${SETSDIR}; ls -lah packages-${PACKAGEVER}.*)

	if [ -f ${BASEDIR}/.pkg-msg ]; then
		echo ">>> WARNING: The build provided additional info."
		cat ${BASEDIR}/.pkg-msg
	fi

	if [ -f ${BASEDIR}/.pkg-err ]; then
		echo ">>> ERROR: The build encountered fatal issues!"
		cat ${BASEDIR}/.pkg-err
		exit 1
	fi

}

setup_packages()
{
	setup_norun ${1}
	extract_packages ${1}
	install_packages ${@} ${PRODUCT_ADDITIONS} ${PRODUCT_CORE}

	# remove package repository
	rm -rf ${1}${PACKAGESDIR}

	# stop blocking start of configd
	rm ${1}/etc/rc.conf.local

	# remove device node required by pkg
	umount -f ${1}/dev
}

_setup_extras_generic()
{
	if [ ! -f ${CONFIGDIR}/extras.conf ]; then
		return
	fi

	unset -f ${2}_hook

	. ${CONFIGDIR}/extras.conf

	if [ -n "$(type ${2}_hook 2> /dev/null)" ]; then
		echo ">>> Begin extra: ${2}_hook"
		${2}_hook ${1}
		echo ">>> End extra: ${2}_hook"
	fi
}

_setup_extras_device()
{
	if [ ! -f ${DEVICEDIR}/${PRODUCT_DEVICE_REAL}.conf ]; then
		return
	fi

	unset -f ${2}_hook

	. ${DEVICEDIR}/${PRODUCT_DEVICE_REAL}.conf

	if [ -n "$(type ${2}_hook 2> /dev/null)" ]; then
		echo ">>> Begin ${PRODUCT_DEVICE_REAL} extra: ${2}_hook"
		${2}_hook ${1}
		echo ">>> End ${PRODUCT_DEVICE_REAL} extra: ${2}_hook"
	fi
}

setup_extras()
{
	_setup_extras_generic ${@}
	_setup_extras_device ${@}
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

setup_efiboot()
{
	local EFIFILE
	local EFIDIR
	local FATBITS
	local FATSIZE

	FATSIZE=${3:-"33292"}
	FATBITS=${4:-"32"}

	EFIDIR="efi/boot"

	if [ ${PRODUCT_ARCH} = "amd64" ]; then
		EFIFILE=bootx64
	elif [ ${PRODUCT_ARCH} = "aarch64" ]; then
		EFIFILE=bootaa64
	else
		echo ">>> Unsupported UEFI architecture: ${PRODUCT_ARCH}" >&2
		exit 1
	fi

	mkdir -p ${1}.d/${EFIDIR}
	cp ${2} ${1}.d/${EFIDIR}/${EFIFILE}.efi

	makefs -t msdos -o fat_type=${FATBITS} -o sectors_per_cluster=1 \
	    -o volume_label=EFISYS -s ${FATSIZE}k ${1} ${1}.d
}

setup_stage()
{
	echo ">>> Setting up stage in ${1}"

	MOUNTDIRS="
/boot/msdos
/dev
/mnt
${SRCDIR}
${PORTSDIR}
${COREDIR}
${PLUGINSDIR}
/
"
	STAGE=${1}

	local PID DIR

	shift

	# kill stale pids for chrooted daemons
	if [ -d ${STAGE}/var/run ]; then
		PIDS=$(find ${STAGE}/var/run -name "*.pid")
		for PID in ${PIDS}; do
			pkill -F ${PID} || echo ">>> Stale PID file ${PID}";
		done
	fi

	# might have been a chroot
	for DIR in ${MOUNTDIRS}; do
		if [ -d ${STAGE}${DIR} ]; then
			umount -f ${STAGE}${DIR} 2> /dev/null || true
		fi
	done

	# remove base system files
	rm -rf ${STAGE} 2> /dev/null ||
	    (chflags -R noschg ${STAGE}; rm -rf ${STAGE} 2> /dev/null)

	# revive directory for next run
	mkdir -p ${STAGE}

	# additional directories if requested
	for DIR in ${@}; do
		mkdir -p ${STAGE}/${DIR}
	done

	# try to clean up dangling md nodes
	for NODE in $(mdconfig -l); do
		mdconfig -d -u ${NODE} || true
	done
}

list_config()
{
	cat ${@} | while read LIST_ORIGIN LIST_IGNORE; do
		eval LIST_ORIGIN=${LIST_ORIGIN}
		if [ "$(echo ${LIST_ORIGIN} | colrm 2)" = "#" ]; then
			continue
		fi
		if [ -n "${LIST_IGNORE}" -a -n "${LIST_MATCH}" ]; then
			for LIST_QUIRK in $(echo ${LIST_IGNORE} | tr ',' ' '); do
				if [ ${LIST_QUIRK} = ${PRODUCT_TARGET} -o \
				     ${LIST_QUIRK} = ${PRODUCT_ARCH} -o \
				     ${LIST_QUIRK} = ${PRODUCT_SSL} ]; then
					continue 2
				fi
			done
		fi
		echo ${LIST_ORIGIN}
	done
}

list_packages()
{
	local LIST_MATCH=1
	local LIST_ENV=${1}
	shift

	if [ -n "${LIST_ENV}" ]; then
		for LIST_ORIGIN in ${LIST_ENV}; do
			echo ${LIST_ORIGIN}
		done
		return
	fi

	list_config ${@}
}
