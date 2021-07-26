# Copyright (c) 2015-2021 Franco Fichtner <franco@opnsense.org>
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

STEPS=		audit arm base boot chroot clean clone compress confirm core \
		distfiles download dvd fingerprint info kernel list make.conf \
		nano packages plugins ports prefetch print rebase release \
		rename rewind serial sign skim test update upload verify \
		vga vm xtools
SCRIPTS=	batch distribution hotfix nightly

.PHONY:		${STEPS} ${SCRIPTS}

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

TOOLSDIR?=	/usr/tools
TOOLSBRANCH?=	master

.if defined(CONFIGDIR)
SETTINGS=	${CONFIGDIR:C/^.*\///}
.else
SETTINGS?=	21.1
.endif

CONFIGDIR?=	${TOOLSDIR}/config/${SETTINGS}

.include "${CONFIGDIR}/build.conf"
.-include "${CONFIGDIR}/build.conf.local"

# Bootstrap the build options if not set:

NAME?=		OPNsense
TYPE?=		${NAME:tl}
SUFFIX?=	# empty
FLAVOUR?=	OpenSSL LibreSSL # first one is default
_ARCH!=		uname -p
ARCH?=		${_ARCH}
ABI?=		${SETTINGS}
KERNEL?=	SMP
ADDITIONS?=	os-dyndns
DEVICE?=	A10
COMSPEED?=	115200
COMPORT?=	0x3f8
UEFI?=		dvd serial vga vm arm
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
COREDIR?=	/usr/core
COREENV?=	CORE_PHP=${PHP} CORE_ABI=${ABI} CORE_PYTHON=${PYTHON}

PLUGINSBRANCH?=	stable/${ABI}
PLUGINSDIR?=	/usr/plugins
PLUGINSENV?=	PLUGIN_PHP=${PHP} PLUGIN_ABI=${ABI} PLUGIN_PYTHON=${PYTHON}

PORTSBRANCH?=	master
PORTSDIR?=	/usr/ports
PORTSENV?=	# empty

PORTSREFURL?=	https://git.hardenedbsd.org/hardenedbsd/ports.git
PORTSREFDIR?=	/usr/hardenedbsd-ports
PORTSREFBRANCH?=hardenedbsd/main

SRCBRANCH?=	stable/${ABI}
SRCDIR?=	/usr/src

# A couple of meta-targets for easy use and ordering:

ports distfiles: base
audit plugins: ports
core: plugins
packages test: core
dvd nano serial vga vm: kernel core
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

.for _VERSION in ABI LUA PERL PHP PYTHON RUBY
VERSIONS+=	PRODUCT_${_VERSION}=${${_VERSION}}
.endfor

VERSIONS+=	PRODUCT_CRYPTO=${FLAVOUR:[1]:tl}

# Expand build steps to launch into the selected
# script with the proper build options set:

.for STEP in ${STEPS}
${STEP}: lint-steps
	${VERBOSE_HIDDEN} cd ${.CURDIR}/build && \
	    sh ${VERBOSE_FLAGS} ./${.TARGET}.sh -a ${ARCH} -F ${KERNEL} \
	    -f "${FLAVOUR}" -n ${NAME} -v ${VERSION} -s ${CONFIGDIR} \
	    -S ${SRCDIR} -P ${PORTSDIR} -p ${PLUGINSDIR} -T ${TOOLSDIR} \
	    -C ${COREDIR} -R ${PORTSREFDIR} -t ${TYPE} -k "${PRIVKEY}" \
	    -K "${PUBKEY}" -l "${SIGNCHK}" -L "${SIGNCMD}" -d ${DEVICE} \
	    -m ${MIRRORS:Ox:[1]} -o "${STAGEDIRPREFIX}" -c ${COMSPEED} \
	    -b ${SRCBRANCH} -B ${PORTSBRANCH} -e ${PLUGINSBRANCH} \
	    -g ${TOOLSBRANCH} -E ${COREBRANCH} -G ${PORTSREFBRANCH} \
	    -H "${COREENV}" -u "${UEFI:tl}" -U "${SUFFIX}" -i ${COMPORT} \
	    -V "${ADDITIONS}" -O "${GITBASE}"  -r "${SERVER}" \
	    -q "${VERSIONS}" -h "${PLUGINSENV}" -I "${UPLOADDIR}" \
	    -D "${EXTRABRANCH}" -A "${PORTSREFURL}" -J "${PORTSENV}" \
	    ${${STEP}_ARGS}
.endfor

.for SCRIPT in ${SCRIPTS}
${SCRIPT}: lint-composite
	${VERBOSE_HIDDEN} cd ${.CURDIR} && FLAVOUR="${FLAVOUR}" \
	    sh ${VERBOSE_FLAGS} ./composite/${SCRIPT}.sh ${${SCRIPT}_ARGS}
.endfor
