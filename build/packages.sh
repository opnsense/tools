#!/bin/sh

# Copyright (c) 2019-2026 Franco Fichtner <franco@opnsense.org>
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

SELF=packages

. ./common.sh

if check_packages ${SELF} ${@}; then
	echo ">>> Step ${SELF} is up to date"
	exit 0
fi

setup_stage ${STAGEDIR}

extract_packages ${STAGEDIR}
remove_packages ${STAGEDIR} ${@}

# The goal for aux packages is that they are part of the packages
# set for nightly builds until they are officially built using the
# "packages" target in which case the only thing that needs to be
# done is stripping the auxiliary packages that are only needed for
# the build and further testing.

for PKG in $(cd ${STAGEDIR}; find .${PACKAGESDIR}/All -type f); do
	PKGNAME=$(basename ${PKG%-[0-9]*})

	# only treat build dependencies as aux packages when they
	# are also not marked as runtime dependencies -- if they
	# already existed they were not added and not marked which
	# means we keep their status quo of runtime depedency
	if [ -f ${STAGEDIR}${PACKAGESDIR}/.Build/${PKGNAME} -a \
	    ! -f ${STAGEDIR}${PACKAGESDIR}/.Run/${PKGNAME} ]; then
		echo ">>> Moving auxiliary package ${PKGNAME}" \
		    >> ${STAGEDIR}/.pkg-msg

		mkdir -p ${STAGEDIR}${PACKAGESDIR}-aux/All
		mv ${STAGEDIR}/${PKG} ${STAGEDIR}${PACKAGESDIR}-aux/All
	fi
done

# remove the hints from the resulting packages set
rm -rf ${STAGEDIR}${PACKAGESDIR}/.Build ${STAGEDIR}${PACKAGESDIR}/.Run

bundle_packages ${STAGEDIR} ${SELF}
