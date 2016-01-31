STEPS=		base clean core distfiles kernel iso \
		memstick nano plugins ports prefetch \
		rebase regress release skim
.PHONY:		${STEPS}

PAGER?=		less

all:
	@cat ${.CURDIR}/README.md | ${PAGER}

# Load the custom options from a file:

.if defined(CONFIG)
.include "${CONFIG}"
.endif

# Bootstrap the build options if not set:

NAME?=		OPNsense
TYPE?=		opnsense-devel
FLAVOUR?=	OpenSSL
SETTINGS?=	16.1
SIGNATURE?=	/root/repo
_VERSION!=	date '+%Y%m%d%H%M'
VERSION?=	${_VERSION}
PORTSREFDIR?=	/usr/freebsd-ports
PLUGINSDIR?=	/usr/plugins
TOOLSDIR?=	/usr/tools
PORTSDIR?=	/usr/ports
COREDIR?=	/usr/core
SRCDIR?=	/usr/src

# A couple of meta-targets for easy use:

src: base kernel
packages: ports plugins core
sets iso memstick nano: src packages
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
${STEP}:
	@cd build && sh ${VERBOSE_FLAGS} ./${.TARGET}.sh \
	    -f ${FLAVOUR} -n ${NAME} -v ${VERSION} -s ${SETTINGS} \
	    -S ${SRCDIR} -P ${PORTSDIR} -p ${PLUGINSDIR} -T ${TOOLSDIR} \
	    -C ${COREDIR} -R ${PORTSREFDIR} -t ${TYPE} -k ${SIGNATURE} \
	    ${${STEP}_ARGS}
.endfor
