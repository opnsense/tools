# Copyright (c) 2015-2019 Franco Fichtner <franco@opnsense.org>
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

STEPS=		arm base boot chroot clean compress confirm core distfiles \
		download dvd info kernel nano plugins ports prefetch print \
		rebase release rename rewind serial sign skim test update \
		upload verify vga vm xtools
SCRIPTS=	batch hotfix nightly
.PHONY:		${STEPS}

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
SETTINGS?=	19.1

CONFIG?=	${TOOLSDIR}/config/${SETTINGS}/build.conf

.-include "${CONFIG}"

# Bootstrap the build options if not set:

NAME?=		OPNsense
TYPE?=		${NAME:tl}
SUFFIX?=	#-devel
FLAVOUR?=	OpenSSL
_ARCH!=		uname -p
ARCH?=		${_ARCH}
KERNEL?=	SMP
QUICK?=		#yes
ADDITIONS?=	os-dyndns${SUFFIX}
DEVICE?=	a10
SPEED?=		115200
UEFI?=		yes
GITBASE?=	https://github.com/opnsense
MIRRORS?=	https://opnsense.c0urier.net \
		http://mirrors.nycbug.org/pub/opnsense \
		http://mirror.wdc1.us.leaseweb.net/opnsense \
		http://mirror.sfo12.us.leaseweb.net/opnsense \
		http://mirror.fra10.de.leaseweb.net/opnsense \
		http://mirror.ams1.nl.leaseweb.net/opnsense
SERVER?=	user@does.not.exist
UPLOADDIR?=	# empty
_VERSION!=	date '+%Y%m%d%H%M'
VERSION?=	${_VERSION}
STAGEDIRPREFIX?=/usr/obj
# XXX GITBASE modifier
PORTSREFBASE?=	https://github.com/hardenedbsd
PORTSREFDIR?=	/usr/hardenedbsd-ports
PORTSREFBRANCH?=master
PLUGINSENV?=	PLUGIN_PHP=${PHP} PLUGIN_ABI=${SETTINGS}
PLUGINSDIR?=	/usr/plugins
PLUGINSBRANCH?=	master
PORTSDIR?=	/usr/ports
PORTSBRANCH?=	master
COREDIR?=	/usr/core
COREBRANCH?=	master
COREENV?=	CORE_PHP=${PHP} CORE_ABI=${SETTINGS}
SRCDIR?=	/usr/src
SRCBRANCH?=	master

# for ports and core
DEVELBRANCH?=	#master

# A couple of meta-targets for easy use and ordering:

ports distfiles: base
plugins: ports
core: plugins
packages test: core
dvd nano serial vga vm: packages kernel
sets: distfiles packages kernel
images: dvd nano serial vga vm # arm
release: dvd nano serial vga

# Expand target arguments for the script append:

.for TARGET in ${.TARGETS}
_TARGET=	${TARGET:C/\-.*//}
.if ${_TARGET} != ${TARGET}
${_TARGET}_ARGS+=	${TARGET:C/^[^\-]*(\-|\$)//:S/,/ /g}
${TARGET}: ${_TARGET}
.endif
.endfor

.if "${VERBOSE}" != ""
VERBOSE_FLAGS=	-x
.else
VERBOSE_HIDDEN=	@
.endif

.for _VERSION in PERL PHP PYTHON2 PYTHON3 RUBY
VERSIONS+=	PRODUCT_${_VERSION}=${${_VERSION}}
.endfor

# Expand build steps to launch into the selected
# script with the proper build options set:

.for STEP in ${STEPS}
${STEP}: lint-steps
	${VERBOSE_HIDDEN} cd ${.CURDIR}/build && \
	    sh ${VERBOSE_FLAGS} ./${.TARGET}.sh -a ${ARCH} -F ${KERNEL} \
	    -f ${FLAVOUR} -n ${NAME} -v ${VERSION} -s ${SETTINGS} \
	    -S ${SRCDIR} -P ${PORTSDIR} -p ${PLUGINSDIR} -T ${TOOLSDIR} \
	    -C ${COREDIR} -R ${PORTSREFDIR} -t ${TYPE} -k "${PRIVKEY}" \
	    -K "${PUBKEY}" -l "${SIGNCHK}" -L "${SIGNCMD}" -d ${DEVICE} \
	    -m ${MIRRORS:Ox:[1]} -o "${STAGEDIRPREFIX}" -c ${SPEED} \
	    -b ${SRCBRANCH} -B ${PORTSBRANCH} -e ${PLUGINSBRANCH} \
	    -g ${TOOLSBRANCH} -E ${COREBRANCH} -G ${PORTSREFBRANCH} \
	    -H "${COREENV}" -Q "${QUICK}" -u "${UEFI:tl}" -U "${SUFFIX}" \
	    -V "${ADDITIONS}" -O "${GITBASE}"  -r "${SERVER}" \
	    -q "${VERSIONS}" -h "${PLUGINSENV}" -I "${UPLOADDIR}" \
	    -D "${DEVELBRANCH}" ${${STEP}_ARGS}
.endfor

.for SCRIPT in ${SCRIPTS}
${SCRIPT}: lint-composite
	${VERBOSE_HIDDEN} cd ${.CURDIR} && sh ${VERBOSE_FLAGS} \
	    ./composite/${SCRIPT}.sh ${${SCRIPT}_ARGS}
.endfor
