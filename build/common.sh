#!/bin/sh

# Copyright (c) 2014-2020 Franco Fichtner <franco@opnsense.org>
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

OPTS="A:a:B:b:C:c:D:d:E:e:F:f:G:g:H:h:I:K:k:L:l:m:n:O:o:P:p:q:R:r:S:s:T:t:U:u:v:V:"

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
		export PRODUCT_SPEED=${OPTARG}
		;;
	d)
		export PRODUCT_DEVICE_REAL=${OPTARG}
		export PRODUCT_DEVICE=${OPTARG}
		;;
	D)
		export DEVELBRANCH=${OPTARG}
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
	f)
		export PRODUCT_FLAVOUR=${OPTARG%% *}
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
	I)
		export UPLOADDIR=${OPTARG}
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
	O)	export PRODUCT_GITBASE=${OPTARG}
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
	q)
		for _VERSION in ${OPTARG}; do
			eval "export ${_VERSION}"
		done
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
		export PRODUCT_SETTINGS=${OPTARG}
		;;
	T)
		export TOOLSDIR=${OPTARG}
		;;
	t)
		export PRODUCT_TYPE=${OPTARG}
		;;
	U)
		case "${OPTARG}" in
		''|-devel)
			export PRODUCT_SUFFIX=${OPTARG}
			;;
		*)
			echo "SUFFIX wants empty string or '-devel'" >&2
			exit 1
			;;
		esac
		;;
	u)
		if [ "${OPTARG}" = "yes" ]; then
			export PRODUCT_UEFI=${OPTARG}
		fi
		;;
	v)
		export PRODUCT_VERSION=${OPTARG}
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

shift $((${OPTIND} - 1))

CHECK_MISSING="
PRODUCT_NAME
PRODUCT_TYPE
PRODUCT_ARCH
PRODUCT_FLAVOUR
PRODUCT_VERSION
PRODUCT_SETTINGS
PRODUCT_MIRROR
PRODUCT_DEVICE_REAL
PRODUCT_SPEED
PRODUCT_SERVER
PRODUCT_PHP
PRODUCT_PERL
PRODUCT_PYTHON
PRODUCT_RUBY
PRODUCT_KERNEL
PRODUCT_GITBASE
PLUGINSBRANCH
PLUGINSDIR
PORTSBRANCH
PORTSDIR
PORTSREFDIR
TOOLSBRANCH
TOOLSDIR
COREBRANCH
COREDIR
SRCBRANCH
SRCDIR
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
export CONFIGDIR="${TOOLSDIR}/config/${PRODUCT_SETTINGS}"
export DEVICEDIR="${TOOLSDIR}/device"
export PACKAGESDIR="/.pkg"

if [ ! -f ${DEVICEDIR}/${PRODUCT_DEVICE_REAL}.conf ]; then
	echo ">>> No configuration found for device ${PRODUCT_DEVICE_REAL}." >&2
	exit 1
fi

# load device-specific environment
. ${DEVICEDIR}/${PRODUCT_DEVICE_REAL}.conf

# reload the kernel according to device specifications
export PRODUCT_KERNEL="${PRODUCT_KERNEL}${PRODUCT_DEVICE+"-${PRODUCT_DEVICE}"}"

# define and bootstrap target directories
export STAGEDIR="${STAGEDIRPREFIX}${CONFIGDIR}/${PRODUCT_FLAVOUR}:${PRODUCT_ARCH}"
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
export PRODUCT_RELEASE="${PRODUCT_NAME}${PRODUCT_SUFFIX}-${PRODUCT_VERSION}-${PRODUCT_FLAVOUR}"
export PRODUCT_CORES="${PRODUCT_TYPE} ${PRODUCT_TYPE}-devel"
export PRODUCT_CORE="${PRODUCT_TYPE}${PRODUCT_SUFFIX}"
export PRODUCT_PLUGINS="os-*"
export PRODUCT_PLUGIN="os-*${PRODUCT_SUFFIX}"

# get the current version for the selected source repository
eval export SRC$(grep ^REVISION= ${SRCDIR}/sys/conf/newvers.sh)
export SRCABI="FreeBSD:${SRCREVISION%%.*}:${PRODUCT_ARCH}"

case "${SELF}" in
confirm|fingerprint|info|print)
	;;
*)
	if [ -z "${PRINT_ENV_SKIP}" ]; then
		export PRINT_ENV_SKIP=1
		env | sort
	fi
	echo ">>> Running build step: ${SELF}"
	;;
esac

PKGBIN=$(which pkg || true)

for WANT in git ${PRODUCT_WANTS}; do
	if ! ${PKGBIN} info ${WANT} > /dev/null; then
		echo ">>> Required build package '${WANT}' is not installed." >&2
		exit 1
	fi
done

git_reset()
{
	git -C ${1} clean -xdqf .
	REPO_TAG=${2}
	if [ -z "${REPO_TAG}" ]; then
		git_tag ${1} ${PRODUCT_VERSION}
	fi
	git -C ${1} reset --hard ${REPO_TAG}
}

git_fetch()
{
	echo ">>> Fetching ${1}:"

	git -C ${1} fetch --tags --prune origin
}

git_clone()
{
	if [ -d "${1}/.git" ]; then
		return
	fi

	if [ -d "${1}" ]; then
		echo -n ">>> Removing ${1}... "
		rm -r "${1}"
		echo "done"
	else
		mkdir -p $(dirname ${1})
	fi

	echo ">>> Cloning ${1}:"

	URL=${2}

	if [ -z "${URL}" ]; then
		URL=${PRODUCT_GITBASE}/$(basename ${1})
	fi

	git clone "${URL}" ${1}
}

git_pull()
{
	echo ">>> Pulling branch ${2} of ${1}:"

	git -C ${1} checkout ${2}
	git -C ${1} pull
}

git_describe()
{
	HEAD=${2:-"HEAD"}

	VERSION=$(git -C ${1} describe --abbrev=0 --always ${HEAD})
	REVISION=$(git -C ${1} rev-list --count ${VERSION}..${HEAD})
	COMMENT=$(git -C ${1} rev-list --max-count=1 ${HEAD} | cut -c1-9)
	BRANCH=$(git -C ${1} rev-parse --abbrev-ref ${HEAD})

	if [ "${REVISION}" != "0" ]; then
		# must construct full version string manually
		VERSION=${VERSION}_${REVISION}
	fi

	export REPO_VERSION=${VERSION}
	export REPO_COMMENT=${COMMENT}
	export REPO_BRANCH=${BRANCH}
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
	if [ ${PRODUCT_HOST} = ${PRODUCT_ARCH} ]; then
		return
	fi

	echo ">>> Cleaning up xtools in ${1}"

	rm -f ${1}/usr/bin/qemu-*-static ${1}/etc/rc.conf.local

	XTOOLS_SET=$(find ${SETSDIR} -name "xtools-*-${PRODUCT_ARCH}.txz")
	if [ -z "${XTOOLS_SET}" ]; then
		return
	fi

	XTOOLS=
	for XTOOL in $(tar tf ${XTOOLS_SET}); do
		if [ -d ${1}/${XTOOL} ]; then
			continue
		fi
		XTOOLS="${XTOOLS} ${XTOOL}"
	done

	tar -C ${1} -xpf ${SETSDIR}/base-*-${PRODUCT_ARCH}${PRODUCT_DEVICE+"-${PRODUCT_DEVICE}"}.txz ${XTOOLS}
}

setup_xtools()
{
	if [ ${PRODUCT_HOST} = ${PRODUCT_ARCH} ]; then
		return
	fi

	echo ">>> Setting up xtools in ${1}"

	# additional emulation layer so that chroot
	# looks like a native environment later on
	mkdir -p ${1}/usr/local/bin
	case ${PRODUCT_TARGET} in
	arm64)
		cp /usr/local/bin/qemu-${PRODUCT_ARCH}-static ${1}/usr/local/bin
		;;
	*)
		cp /usr/local/bin/qemu-${PRODUCT_TARGET}-static ${1}/usr/local/bin
		;;
	esac
	/usr/local/etc/rc.d/qemu_user_static onerestart

	# copy the native toolchain for extra speed
	XTOOLS_SET=$(find ${SETSDIR} -name "xtools-*-${PRODUCT_ARCH}.txz")
	if [ -n "${XTOOLS_SET}" ]; then
		tar -C ${1} -xpf ${XTOOLS_SET}
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

	# embed target architecture
	echo "${PRODUCT_ARCH}" > ${VERSIONDIR}/${3}.arch

	# embed version for update checks
	echo "${REPO_VERSION}" > ${VERSIONDIR}/${3}

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

setup_set()
{
	tar -C ${1} -xJpf ${2}
	rm -f {1}/.abi_hint
}

generate_set()
{
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

	echo -n ">>> Creating ${PRODUCT_SETTINGS} signature for ${1}: "

	openssl dgst -sha256 -sign "${PRODUCT_PRIVKEY}" "${1}" | \
	    openssl base64 > "${2}"
	openssl base64 -d -in "${2}" > "${2}.tmp"
	openssl dgst -sha256 -verify "${PRODUCT_PUBKEY}" \
	    -signature "${2}.tmp" "${1}"
	rm "${2}.tmp"
}

check_image()
{
	SELF=${1}
	SKIP=${2}

	IMAGE=$(find ${IMAGESDIR} -name "*-${SELF}-${PRODUCT_ARCH}${PRODUCT_DEVICE+"-${PRODUCT_DEVICE}"}.*")

	if [ -f "${IMAGE}" -a -z "${SKIP}" ]; then
		echo ">>> Reusing ${SELF} image: ${IMAGE}"
		exit 0
	fi
}

check_packages()
{
	SELF=${1}
	SKIP=${2}

	PACKAGESET=$(find ${SETSDIR} -name "packages-*-${PRODUCT_FLAVOUR}-${PRODUCT_ARCH}.tar")

	if [ -z "${SELF}" -o -z "${PACKAGESET}" -o -n "${SKIP}" ]; then
		return
	fi

	DONE=$(tar tf ${PACKAGESET} | grep "^\./\.${SELF}_done\$" || true)
	if [ -n "${DONE}" ]; then
		echo ">>> Packages (${SELF}) are up to date"
		exit 0
	fi
}

extract_packages()
{
	echo ">>> Extracting packages in ${1}"

	BASEDIR=${1}

	rm -rf ${BASEDIR}${PACKAGESDIR}/All
	mkdir -p ${BASEDIR}${PACKAGESDIR}/All

	PACKAGESET=$(find ${SETSDIR} -name "packages-*-${PRODUCT_FLAVOUR}-${PRODUCT_ARCH}.tar")
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
	shift
	PKGLIST=${@}

	echo ">>> Searching packages in ${BASEDIR}: ${PKGLIST}"

	for PKG in ${PKGLIST}; do
		if [ -n "$(find ${BASEDIR}${PACKAGESDIR}/All \
		    -name "${PKG}-[0-9]*.txz" -type f)" ]; then
			return 0
		fi
	done

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
		    find All -name "${PKG}-[0-9]*.txz" -type f); do
			rm ${BASEDIR}${PACKAGESDIR}/${PKGFILE}
		done
	done
}

cleanup_packages()
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
			PKGGLOBS="${PKGGLOBS} $(make -C ${PORTSDIR}/${PKGORIGIN} -V ${CONFLICTS})"
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
		PKGGLOB=$(echo "${PKG}" | sed 's/[^*]*//')
		PKGSEARCH="-name ${PKG}-[0-9]*.txz"
		PKGFOUND=
		if [ -n "${PKGGLOB}" -a -z "${PRODUCT_SUFFIX}" ]; then
			PKGSEARCH="${PKGSEARCH} ! -name ${PKG}-devel-[0-9]*.txz"
		fi
		for PKGFILE in $({
			cd ${BASEDIR}
			find .${PACKAGESDIR}/All ${PKGSEARCH}
		}); do
			pkg -c ${BASEDIR} add ${PKGFILE}
			PKGFOUND=1
		done
		if [ -z "${PKGFOUND}" ]; then
			echo "Could not find package: ${PKG}" >&2
			exit 1
		fi
	done

	# collect all installed packages (minus locked packages)
	PKGLIST="$(pkg -c ${BASEDIR} query -e "%k != 1" %n)"

	for PKG in ${PKGLIST}; do
		# add, unlike install, is not aware of repositories :(
		pkg -c ${BASEDIR} annotate -qyA ${PKG} \
		    repository ${PRODUCT_NAME}
	done
}

custom_packages()
{
	chroot ${1} /bin/sh -es << EOF
make -C ${2} ${3} FLAVOUR=${PRODUCT_FLAVOUR} PKGDIR=${PACKAGESDIR}/All package
EOF
}

bundle_packages()
{
	BASEDIR=${1}
	SELF=${2}

	shift
	shift

	REDOS=${@}

	git_describe ${PORTSDIR}

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

	if [ -n "${SELF}" ]; then
		# add build marker to set
		if [ ! -f ${BASEDIR}/.pkg-err ]; then
			# append build info if new
			sh ./info.sh > \
			    ${BASEDIR}${PACKAGESDIR}-new/.${SELF}_done
		fi
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
		(
			cd ${BASEDIR}${PACKAGESDIR}-new/Latest
			ln -sfn ../${PKGFILE} ${PKGINFO}.txz
		)
		generate_signature \
		    ${BASEDIR}${PACKAGESDIR}-new/Latest/${PKGINFO}.txz
	done

	# generate index files
	pkg repo ${BASEDIR}${PACKAGESDIR}-new/ ${SIGNARGS}

	echo ${SRCABI} > ${BASEDIR}${PACKAGESDIR}-new/.abi_hint

	sh ./clean.sh packages

	REPO_RELEASE="${REPO_VERSION}-${PRODUCT_FLAVOUR}-${PRODUCT_ARCH}"
	echo -n ">>> Creating package mirror set for ${REPO_RELEASE}... "
	tar -C ${STAGEDIR}${PACKAGESDIR}-new -cf \
	    ${SETSDIR}/packages-${REPO_RELEASE}.tar .
	echo "done"

	generate_signature ${SETSDIR}/packages-${REPO_RELEASE}.tar

	(cd ${SETSDIR}; ls -lah packages-${REPO_RELEASE}.*)
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
	if [ ! -f ${DEVICEDIR}/${PRODUCT_DEVICE}.conf ]; then
		return
	fi

	unset -f ${2}_hook

	. ${DEVICEDIR}/${PRODUCT_DEVICE}.conf

	if [ -n "$(type ${2}_hook 2> /dev/null)" ]; then
		echo ">>> Begin ${PRODUCT_DEVICE} extra: ${2}_hook"
		${2}_hook ${1}
		echo ">>> End ${PRODUCT_DEVICE} extra: ${2}_hook"
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
