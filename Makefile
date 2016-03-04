STEPS=		base chroot clean core distfiles kernel iso \
		memstick nano plugins ports prefetch rebase \
		regress release skim
.PHONY:		${STEPS}

PAGER?=		less

all:
	@cat ${.CURDIR}/README.md | ${PAGER}

lint:
. for STEP in ${STEPS}
	@sh -n ${.CURDIR}/build/${STEP}.sh
. endfor

# Load the custom options from a file:

.if defined(CONFIG)
.include "${CONFIG}"
.endif

# Bootstrap the build options if not set:

NAME?=		OPNsense
TYPE?=		opnsense-devel
FLAVOUR?=	OpenSSL
SETTINGS?=	16.1
MIRRORS?=	https://opnsense.c0urier.net \
		http://mirrors.nycbug.org/pub/opnsense \
		http://mirror.wdc1.us.leaseweb.net/opnsense \
		http://mirror.sfo12.us.leaseweb.net/opnsense \
		http://mirror.fra10.de.leaseweb.net/opnsense \
		http://mirror.ams1.nl.leaseweb.net/opnsense
_VERSION!=	date '+%Y%m%d%H%M'
VERSION?=	${_VERSION}
PRIVKEY?=	/root/repo.key
PUBKEY?=	/root/repo.pub
STAGEDIRPREFIX?=/usr/obj
PORTSREFDIR?=	/usr/freebsd-ports
PLUGINSDIR?=	/usr/plugins
TOOLSDIR?=	/usr/tools
PORTSDIR?=	/usr/ports
COREDIR?=	/usr/core
SRCDIR?=	/usr/src

# A couple of meta-targets for easy use and ordering:

ports: base
plugins: ports
core: plugins
packages: core
iso memstick nano: packages kernel
everything release: iso memstick nano

# Expand target arguments for the script append:

.for TARGET in ${.TARGETS}
_TARGET=	${TARGET:C/\-.*//}
.if ${_TARGET} != ${TARGET}
${_TARGET}_ARGS+=	${TARGET:C/^[^\-]*(\-|\$)//:S/,/ /g}
${TARGET}: ${_TARGET}
.endif
.endfor

.if defined(VERBOSE)
VERBOSE_FLAGS=	-x
.endif

# Expand build steps to launch into the selected
# script with the proper build options set:

.for STEP in ${STEPS}
${STEP}: lint
	@cd ${.CURDIR}/build && sh ${VERBOSE_FLAGS} ./${.TARGET}.sh \
	    -f ${FLAVOUR} -n ${NAME} -v ${VERSION} -s ${SETTINGS} \
	    -S ${SRCDIR} -P ${PORTSDIR} -p ${PLUGINSDIR} -T ${TOOLSDIR} \
	    -C ${COREDIR} -R ${PORTSREFDIR} -t ${TYPE} -k ${PRIVKEY} \
	    -K ${PUBKEY} -l "${SIGNCHK}" -L "${SIGNCMD}" \
	    -m ${MIRRORS:Ox:[1]} -o "${STAGEDIRPREFIX}" ${${STEP}_ARGS}
.endfor
