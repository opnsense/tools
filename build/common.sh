#!/bin/sh

# Copyright (c) 2014-2017 Franco Fichtner <franco@opnsense.org>
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

OPTS="a:B:b:C:c:d:E:e:F:f:G:g:H:K:k:L:l:m:n:O:o:P:p:Q:q:R:S:s:T:t:U:u:v:V:"

while getopts ${OPTS} OPT; do
	case ${OPT} in
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
		export PRODUCT_DEVICE=${OPTARG}
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
		export PRODUCT_FLAVOUR=${OPTARG}
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
	Q)
		export PRODUCT_QUICK=${OPTARG}
		;;
	q)
		export PRODUCT_PHP=${OPTARG}
		;;
	R)
		export PORTSREFDIR=${OPTARG}
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

if [ -z "${PRODUCT_NAME}" -o \
    -z "${PRODUCT_TYPE}" -o \
    -z "${PRODUCT_ARCH}" -o \
    -z "${PRODUCT_FLAVOUR}" -o \
    -z "${PRODUCT_VERSION}" -o \
    -z "${PRODUCT_SETTINGS}" -o \
    -z "${PRODUCT_MIRROR}" -o \
    -z "${PRODUCT_DEVICE}" -o \
    -z "${PRODUCT_SPEED}" -o \
    -z "${PRODUCT_PHP}" -o \
    -z "${PRODUCT_KERNEL}" -o \
    -z "${PRODUCT_GITBASE}" -o \
    -z "${PLUGINSBRANCH}" -o \
    -z "${PLUGINSDIR}" -o \
    -z "${PORTSBRANCH}" -o \
    -z "${PORTSDIR}" -o \
    -z "${PORTSREFDIR}" -o \
    -z "${TOOLSBRANCH}" -o \
    -z "${TOOLSDIR}" -o \
    -z "${COREBRANCH}" -o \
    -z "${COREDIR}" -o \
    -z "${SRCBRANCH}" -o \
    -z "${SRCDIR}" ]; then
	echo "${0}: Missing argument" >&2
	exit 1
fi

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
export STAGEDIR="${STAGEDIRPREFIX}${CONFIGDIR}/${PRODUCT_FLAVOUR}:${PRODUCT_ARCH}"
export DEVICEDIR="${TOOLSDIR}/device"
export PACKAGESDIR="/.pkg"

# define and bootstrap target directories
export TARGETDIRPREFIX="/usr/local/opnsense"
export TARGETDIR="${TARGETDIRPREFIX}/build/${PRODUCT_SETTINGS}/${PRODUCT_ARCH}"
export IMAGESDIR="${TARGETDIR}/images"
export LOGSDIR="${TARGETDIR}/logs"
export SETSDIR="${TARGETDIR}/sets"
mkdir -p ${IMAGESDIR} ${SETSDIR} ${LOGSDIR}

# automatically expanded product stuff
export PRODUCT_PRIVKEY=${PRODUCT_PRIVKEY:-"${CONFIGDIR}/repo.key"}
export PRODUCT_PUBKEY=${PRODUCT_PUBKEY:-"${CONFIGDIR}/repo.pub"}
export PRODUCT_SIGNCMD=${PRODUCT_SIGNCMD:-"${TOOLSDIR}/scripts/pkg_sign.sh ${PRODUCT_PUBKEY} ${PRODUCT_PRIVKEY}"}
export PRODUCT_SIGNCHK=${PRODUCT_SIGNCHK:-"${TOOLSDIR}/scripts/pkg_fingerprint.sh ${PRODUCT_PUBKEY}"}
export PRODUCT_RELEASE="${PRODUCT_NAME}-${PRODUCT_VERSION}-${PRODUCT_FLAVOUR}"
export PRODUCT_CORES="${PRODUCT_TYPE} ${PRODUCT_TYPE}-devel"
export PRODUCT_CORE="${PRODUCT_TYPE}${PRODUCT_SUFFIX}"
export PRODUCT_PLUGINS="os-*"
export PRODUCT_PLUGIN="os-*${PRODUCT_SUFFIX}"

if [ "${SELF}" != print -a "${SELF}" != info ]; then
	if [ -z "${PRINT_ENV_SKIP}" ]; then
		export PRINT_ENV_SKIP=1
		env | sort
	fi
	echo ">>> Running build step: ${SELF}"
fi

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

	git -C ${1} fetch --all --prune
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

	git clone "${PRODUCT_GITBASE}/$(basename ${1})" ${1}
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

	tar -C ${1} -xpf ${SETSDIR}/base-*-${PRODUCT_ARCH}.txz ${XTOOLS}
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
	cp /usr/local/bin/qemu-${PRODUCT_TARGET}-static ${1}/usr/local/bin
	/usr/local/etc/rc.d/qemu_user_static onerestart

	# copy the native toolchain for extra speed
	XTOOLS_SET=$(find ${SETSDIR} -name "xtools-*-${PRODUCT_ARCH}.txz")
	if [ -n "${XTOOLS_SET}" ]; then
		tar -C ${1} -xpf ${XTOOLS_SET}
	fi

	# prevent the start of configd in build environments
	echo 'configd_enable="NO"' >> ${1}/etc/rc.conf.local
}

setup_chroot()
{
	# historic glue
	setup_xtools ${1}

	echo ">>> Setting up chroot in ${1}"

	cp /etc/resolv.conf ${1}/etc
	mount -t devfs devfs ${1}/dev
	chroot ${1} /bin/sh /etc/rc.d/ldconfig start

	# prevent the start of configd in build environments
	echo 'configd_enable="NO"' >> ${1}/etc/rc.conf.local
}

build_marker()
{
	MARKER_DISTDIR="$(make -C${SRCDIR}/release -V DISTDIR)/${1}"
	MARKER_OBJDIR="$(make -C${SRCDIR}/release -V .OBJDIR)"
	MARKER_VERDIR="/usr/local/opnsense/version"

	# reset the distribution directory as well
	setup_stage "${MARKER_OBJDIR}/${MARKER_DISTDIR}"

	MARKER="${MARKER_OBJDIR}/${MARKER_DISTDIR}/${MARKER_VERDIR}"

	mkdir -p "${MARKER}"

	echo "${REPO_VERSION}-${PRODUCT_ARCH}" > "${MARKER}/${1}"
}

setup_base()
{
	echo ">>> Setting up world in ${1}"

	tar -C ${1} -xpf ${SETSDIR}/base-*-${PRODUCT_ARCH}.txz

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

	tar -C ${1} -xpf ${SETSDIR}/kernel-*-${PRODUCT_ARCH}.txz
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
		echo -n ">>> Creating ${PRODUCT_SETTINGS} signature for $(basename ${1})... "
		sha256 -q ${1} | ${PRODUCT_SIGNCMD} > ${1}.sig
		echo "done"
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

	IMAGE=$(find ${IMAGESDIR} -name "*-${SELF}-${PRODUCT_ARCH}.*")

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
	fi
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
make -C ${2} ${3} FLAVOUR=${PRODUCT_FLAVOUR} WRKDIR=/work \
    PKGDIR=${PACKAGESDIR}/All package
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
		MARKER="${BASEDIR}${PACKAGESDIR}-new/.${SELF}_done"
		if [ ! -f ${MARKER} ]; then
			# append build info if new
			sh ./info.sh > ${MARKER}
		fi
		touch ${MARKER}
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

	sh ./clean.sh packages

	REPO_RELEASE="${REPO_VERSION}-${PRODUCT_FLAVOUR}-${PRODUCT_ARCH}"
	echo -n ">>> Creating package mirror set for ${REPO_RELEASE}... "
	tar -C ${STAGEDIR}${PACKAGESDIR}-new -cf \
	    ${SETSDIR}/packages-${REPO_RELEASE}.tar .
	echo "done"

	generate_signature ${SETSDIR}/packages-${REPO_RELEASE}.tar
}

clean_packages()
{
	rm -rf ${1}${PACKAGESDIR}
}

setup_packages()
{
	extract_packages ${1}
	install_packages ${@} ${PRODUCT_CORE} ${PRODUCT_ADDITIONS}
	clean_packages ${1}
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
			pkill -F ${PID} || true;
		done
	fi

	# might have been a chroot
	for DIR in ${MOUNTDIRS}; do
		if [ -d ${STAGE}${DIR} ]; then
			umount ${STAGE}${DIR} 2> /dev/null || true
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
