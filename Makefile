# Copyright (c) 2015-2022 Franco Fichtner <franco@opnsense.org>
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

STEPS=		audit arm base boot chroot clean clone compress confirm \
		connect core distfiles download dvd fingerprint info \
		kernel list make.conf nano options packages plugins ports \
		prefetch print rebase release rename rewind serial sign \
		skim test update upload verify vga vm xtools
SCRIPTS=	batch distribution factory hotfix nightly

.PHONY:		fix ${STEPS} ${SCRIPTS}

PAGER?=		less

.MAKE.JOB.PREFIX?=	# tampers with some of our make invokes

all:
	@cat ${.CURDIR}/README.md | ${PAGER}

lint-steps:
.for STEP in common ${STEPS}
	@sh -n ${.CURDIR}/build/${STEP}.sh
.endfor

lint-composite:
.for SCRIPT in ${SCRIPTS}
	@sh -n ${.CURDIR}/composite/${SCRIPT}.sh
.endfor

lint: lint-steps lint-composite

# Special vars to load early build.conf settings:

ROOTDIR?=	/usr

TOOLSDIR?=	${ROOTDIR}/tools
TOOLSBRANCH?=	master

.if defined(CONFIGDIR)
_CONFIGDIR=	${CONFIGDIR}
.elif defined(SETTINGS)
_CONFIGDIR=	${TOOLSDIR}/config/${SETTINGS}
.elif !defined(CONFIGDIR)
__CONFIGDIR!=	find -s ${TOOLSDIR}/config -name "build.conf" -type f
.for DIR in ${__CONFIGDIR}
. if exists(${DIR}) && empty(_CONFIGDIR)
_CONFIGDIR=	${DIR:C/\/build\.conf$//}
. endif
.endfor
.endif

.-include "${_CONFIGDIR}/build.conf.local"
.include "${_CONFIGDIR}/build.conf"

# Bootstrap the build options if not set:

NAME?=		OPNsense
TYPE?=		${NAME:tl}
SUFFIX?=	# empty
FLAVOUR?=	OpenSSL LibreSSL # first one is default
_ARCH!=		uname -p
ARCH?=		${_ARCH}
ABI?=		${_CONFIGDIR:C/^.*\///}
KERNEL?=	SMP
ADDITIONS?=	# empty
DEBUG?=		# empty
DEVICE?=	A10
COMSPEED?=	115200
UEFI?=		arm dvd serial vga vm
ZFS?=		# empty
GITBASE?=	https://github.com/opnsense
MIRRORS?=	https://opnsense.c0urier.net \
		http://mirrors.nycbug.org/pub/opnsense \
		http://mirror.wdc1.us.leaseweb.net/opnsense \
		http://mirror.sfo12.us.leaseweb.net/opnsense \
		http://mirror.fra10.de.leaseweb.net/opnsense \
		http://mirror.ams1.nl.leaseweb.net/opnsense
SERVER?=	user@does.not.exist
UPLOADDIR?=	.
_VERSION!=	date '+%Y%m%d%H%M'
VERSION?=	${_VERSION}
STAGEDIRPREFIX?=/usr/obj

EXTRABRANCH?=	# empty


COREBRANCH?=	stable/${ABI}
COREDIR?=	${ROOTDIR}/core
COREENV?=	CORE_PHP=${PHP} CORE_ABI=${ABI} CORE_PYTHON=${PYTHON}

PLUGINSBRANCH?=	stable/${ABI}
PLUGINSDIR?=	${ROOTDIR}/plugins
PLUGINSENV?=	PLUGIN_PHP=${PHP} PLUGIN_ABI=${ABI} PLUGIN_PYTHON=${PYTHON}

PORTSBRANCH?=	master
PORTSDIR?=	${ROOTDIR}/ports
PORTSENV?=	# empty

PORTSREFURL?=	https://git.FreeBSD.org/ports.git
PORTSREFDIR?=	${ROOTDIR}/freebsd-ports
PORTSREFBRANCH?=main

SRCBRANCH?=	stable/${ABI}
SRCDIR?=	${ROOTDIR}/src

# A couple of meta-targets for easy use and ordering:

kernel ports distfiles: base
audit plugins: ports
core: plugins
packages test: core
arm dvd nano serial vga vm: kernel core
sets: kernel distfiles packages
images: dvd nano serial vga vm
release: dvd nano serial vga

# Expand target arguments for the script append:

.for TARGET in ${.TARGETS}
_TARGET=	${TARGET:C/\-.*//}
.if ${_TARGET} != ${TARGET}
.if ${SCRIPTS:M${_TARGET}}
${_TARGET}_ARGS+=	${TARGET:C/^[^\-]*(\-|\$)//}
.else
${_TARGET}_ARGS+=	${TARGET:C/^[^\-]*(\-|\$)//:S/,/ /g}
.endif
${TARGET}: ${_TARGET}
.endif
.endfor

.if "${VERBOSE}" != ""
VERBOSE_FLAGS=	-x
.else
VERBOSE_HIDDEN=	@
.endif

.for _VERSION in ABI DEBUG LUA PERL PHP PYTHON RUBY VERSION ZFS
VERSIONS+=	PRODUCT_${_VERSION}=${${_VERSION}}
.endfor

VERSIONS+=	PRODUCT_CRYPTO=${FLAVOUR:[1]:tl}

# Expand build steps to launch into the selected
# script with the proper build options set:

.for STEP in ${STEPS}
${STEP}: lint-steps
	${VERBOSE_HIDDEN} cd ${.CURDIR}/build && \
	    sh ${VERBOSE_FLAGS} ./${.TARGET}.sh -a ${ARCH} -F ${KERNEL} \
	    -f "${FLAVOUR}" -n ${NAME} -v "${VERSIONS}" -s ${_CONFIGDIR} \
	    -S ${SRCDIR} -P ${PORTSDIR} -p ${PLUGINSDIR} -T ${TOOLSDIR} \
	    -C ${COREDIR} -R ${PORTSREFDIR} -t ${TYPE} -k "${PRIVKEY}" \
	    -K "${PUBKEY}" -l "${SIGNCHK}" -L "${SIGNCMD}" -d ${DEVICE} \
	    -m ${MIRRORS:Ox:[1]} -o "${STAGEDIRPREFIX}" -c ${COMSPEED} \
	    -b ${SRCBRANCH} -B ${PORTSBRANCH} -e ${PLUGINSBRANCH} \
	    -g ${TOOLSBRANCH} -E ${COREBRANCH} -G ${PORTSREFBRANCH} \
	    -H "${COREENV}" -u "${UEFI:tl}" -U "${SUFFIX}" \
	    -V "${ADDITIONS}" -O "${GITBASE}"  -r "${SERVER}" \
	    -h "${PLUGINSENV}" -I "${UPLOADDIR}" -D "${EXTRABRANCH}" \
	    -A "${PORTSREFURL}" -J "${PORTSENV}" ${${STEP}_ARGS}
.endfor

.for SCRIPT in ${SCRIPTS}
${SCRIPT}: lint-composite
	${VERBOSE_HIDDEN} cd ${.CURDIR} && FLAVOUR="${FLAVOUR}" \
	    sh ${VERBOSE_FLAGS} ./composite/${SCRIPT}.sh ${${SCRIPT}_ARGS}
.endfor

_OS!=	uname -r
_OS:=	${_OS:C/-.*//}
.if "${_OS}" != "${OS}"
.error Expected OS version ${OS} for ${_CONFIGDIR}; to continue anyway set OS=${_OS}
.endif


# Rules for establishing OPNsense repos as the package source.   This is
# to fix the pkg versioning issues with upstream.  This fixes the build
# machine itself.

/usr/local/bin/git:
	pkg install -y git

/root/pkg-static:
	cp /usr/local/sbin/pkg-static /root/pkg-static

fix: /usr/local/bin/git update /root/pkg-static
	/root/pkg-static info | \
		awk '{print $$1}' | \
		xargs /root/pkg-static delete -fy
	cp -a ${COREDIR}/src/etc/pkg /usr/local/etc/
	mv /usr/local/etc/pkg/repos/FreeBSD.conf.shadow \
		/usr/local/etc/pkg/repos/FreeBSD.conf
	opnsensecfg=/usr/local/etc/pkg/repos/OPNsense.conf ; \
	echo "OPNsense: {" > "$${opnsensecfg}" ; \
	echo "    fingerprints: \"/usr/local/etc/pkg/fingerprints/OPNsense\"," >> "$${opnsensecfg}" ; \
	echo "    url: \"https://pkg.opnsense.org/FreeBSD:13:${ARCH}/${ABI}/latest\"," >> "$${opnsensecfg}" ; \
	echo "    enabled: yes," >> "$${opnsensecfg}" ; \
	echo "    mirror_type: \"srv\"," >> "$${opnsensecfg}" ; \
	echo "    signature_type: \"fingerprints\"" >> "$${opnsensecfg}" ; \
	echo "}" >> "$${opnsensecfg}"
	/root/pkg-static install -y pkg
	rm -f /root/pkg-static
	rm -rf /var/db/pkg/
	pkg install -y pkg
