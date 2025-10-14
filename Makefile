# Copyright (c) 2015-2025 Franco Fichtner <franco@opnsense.org>
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
		kernel list make.conf nano obsolete options packages \
		plugins ports prefetch print rebase release rename \
		serial sign skim sync test tests update upload \
		verify vga vm xtools
SCRIPTS=	custom distribution factory hotfix nightly pkgver watch

.PHONY:		${STEPS} ${SCRIPTS}

PAGER?=		less

.MAKE.JOB.PREFIX?=	# tampers with some of our make invokes

all:
	@cat ${.CURDIR}/README.md | ${PAGER}

updateportsref:
	@make -C ${TOOLSDIR} update-portsref

skim: updateportsref

lint-steps:
.for STEP in common ${STEPS}
	@sh -n ${TOOLSDIR}/build/${STEP}.sh
.endfor

lint-composite:
.for SCRIPT in ${SCRIPTS}
	@sh -n ${TOOLSDIR}/composite/${SCRIPT}.sh
.endfor

lint: lint-steps lint-composite

# Special vars to load early build.conf settings:

ROOTDIR?=	/usr

TOOLSDIR?=	${ROOTDIR}/tools
TOOLSBRANCH?=	master

_OS!=	uname -r
_OS:=	${_OS:C/-.*//}

.if defined(CONFIGDIR)
_CONFIGDIR=	${CONFIGDIR}
.elif defined(SETTINGS)
_CONFIGDIR=	${.CURDIR}/config/${SETTINGS}
.elif !defined(CONFIGDIR)
__CONFIGDIR!=	find -s ${.CURDIR}/config -name "build.conf" -type f
.for DIR in ${__CONFIGDIR}
. if exists(${DIR}) && empty(_CONFIGDIR)
_CONFIGOS!=	grep '^OS?*=' ${DIR}
.  if ${_CONFIGOS:[2]} == ${_OS}
_CONFIGDIR=	${DIR:C/\/build\.conf$//}
.  endif
. endif
.endfor
.endif

.if empty(_CONFIGDIR)
.error Found no configuration matching OS version "${_OS}"
.endif

.-include "${_CONFIGDIR}/build.conf.local"
.include "${_CONFIGDIR}/build.conf"

_ARCH!=		uname -p
_VERSION!=	date '+%Y%m%d%H%M'

# Bootstrap the build options if not set:

ABI?=		${_CONFIGDIR:C/^.*\///}
ADDITIONS?=	# empty
ARCH?=		${_ARCH}
COMSPEED?=	115200
DEBUG?=		# empty
DEVICE?=	A10
KERNEL?=	SMP
NAME?=		OPNsense
SUFFIX?=	# empty
TYPE?=		${NAME:tl}
UEFI?=		arm dvd serial vga vm
VERSION?=	${_VERSION}
ZFS?=		# empty

GITBASE?=	https://github.com/opnsense
MIRRORS?=	https://opnsense.c0urier.net \
		https://mirrors.nycbug.org/pub/opnsense \
		https://mirror.wdc1.us.leaseweb.net/opnsense \
		https://mirror.sfo12.us.leaseweb.net/opnsense \
		https://mirror.fra10.de.leaseweb.net/opnsense \
		https://mirror.ams1.nl.leaseweb.net/opnsense
SERVER?=	user@does.not.exist
UPLOADDIR?=	.

STAGEDIRPREFIX?=/usr/obj

EXTRABRANCH?=	# empty

COREBRANCH?=	stable/${ABI}
COREVERSION?=	# empty
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

.for _VERSION in ABI APACHE DEBUG LUA PERL PHP PYTHON RUBY SSL VERSION ZFS
VERSIONS+=	PRODUCT_${_VERSION}=${${_VERSION}}
.endfor

# Expand build steps to launch into the selected
# script with the proper build options set:

.for STEP in ${STEPS}
${STEP}: lint-steps
	@echo ">>> Executing build step ${STEP} on ${_CONFIGDIR:C/.*\///}" >&2
	${VERBOSE_HIDDEN} cd ${TOOLSDIR}/build && \
	    sh ${VERBOSE_FLAGS} ./${.TARGET}.sh -a ${ARCH} -F ${KERNEL} \
	    -n ${NAME} -v "${VERSIONS}" -s ${_CONFIGDIR} \
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
	${VERBOSE_HIDDEN} cd ${.CURDIR} && sh ${VERBOSE_FLAGS} \
	    ${TOOLSDIR}/composite/${SCRIPT}.sh ${${SCRIPT}_ARGS}
.endfor

.if "${_OS}" != "${OS}"
.error Expected OS version ${OS} for ${_CONFIGDIR}; to continue anyway set OS=${_OS}
.endif
