#!/bin/sh

# Copyright (c) 2026 Franco Fichtner <franco@opnsense.org>
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

SELF=pkgbase

. ./common.sh

PKGBASESET=$(find_set pkgbase)

if [ -f "${PKGBASESET}" -a -z "${1}" ]; then
	echo ">>> Keeping pkgbase set: ${PKGBASESET}"
	echo ">>> Have you re-run 'base' and 'kernel' yet?"
	exit 0
fi

echo ">>> Refreshing pkgbase set: ${PKGBASESET}"

git_branch ${SRCDIR} ${SRCBRANCH} SRCBRANCH
git_version ${SRCDIR}

setup_stage ${STAGEDIR} work

if [ -f "${PKGBASESET}" ]; then
	tar -C ${STAGEDIR} -xpf ${PKGBASESET}
fi

MAKE_ARGS="
TARGET_ARCH=${PRODUCT_ARCH}
TARGET=${PRODUCT_TARGET}
KERNCONF=${PRODUCT_KERNEL}
SRCCONF=${CONFIGDIR}/src.conf
WITHOUT_DEBUG_FILES=yes
PKG_NAME_PREFIX=${PRODUCT_NAME}
PKG_VERSION=${PRODUCT_VERSION}
PKG_TIMESTAMP=${PRODUCT_TIMESTAMP}
__MAKE_CONF=
"

for DIR in $(find ${STAGEDIR} -d 2); do
	if [ "$(basename ${DIR})" = "${PRODUCT_VERSION}" ]; then
		echo "Version already built: ${PRODUCT_VERSION}" >&2
		exit 1
	fi
done

# Enforce a full run first: update-packages fails
# to do its job without it.  It beats running the
# update-packages target twice.
REPODIR=${STAGEDIR}/work
${ENV_FILTER} make -s -C${SRCDIR} packages ${MAKE_ARGS} REPODIR=${REPODIR}

# If we can build a partial update do it now and
# remove the full set of regenerated ones.
if [ -L ${STAGEDIR}/${SRCABI}/latest ]; then
	rm -rf ${STAGEDIR}/work
	REPODIR=${STAGEDIR}
	${ENV_FILTER} make -s -C${SRCDIR} update-packages ${MAKE_ARGS} \
	    REPODIR=${REPODIR}
fi

for DIR in $(find ${REPODIR} -d 2); do
	case "$(basename ${DIR})" in
	latest|${PRODUCT_VERSION})
		;;
	*)
		# remove all obsolete previous version
		rm -rf ${DIR}
		;;
	esac
done

sh ./clean.sh pkgbase

PKGBASESET=${SETSDIR}/pkgbase-${PRODUCT_VERSION}-${PRODUCT_ARCH}.tar
generate_set ${REPODIR} ${PKGBASESET}
generate_signature ${PKGBASESET}
