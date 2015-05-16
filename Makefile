BUILDSCRIPTS=	base kernel ports core iso memstick nano \
		regress clean release
.PHONY:		${BUILDSCRIPTS}

.if defined(CONFIG)
.include "${CONFIG}"
.endif

NAME?=		OPNsense
FLAVOUR?=	OpenSSL
_VERSION!=	date '+%Y%m%d%H%M'
VERSION?=	${_VERSION}

all:
	@cat ${.CURDIR}/README.md | ${PAGER}

source: base kernel
packages: ports core
sets: source packages
images: iso memstick nano
everything: sets images

.for BUILDSCRIPT in ${BUILDSCRIPTS}
${BUILDSCRIPT}:
	@cd build && sh ./${.TARGET}.sh \
	    -f ${FLAVOUR} -n ${NAME} -v ${VERSION} ${ARGS}
.endfor
