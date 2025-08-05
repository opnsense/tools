#!/bin/sh

# Copyright (c) 2014-2023 Franco Fichtner <franco@opnsense.org>
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

SELF=core

. ./common.sh

if check_packages ${SELF} ${@}; then
	echo ">>> Step ${SELF} is up to date"
	exit 0
fi

git_branch ${COREDIR} ${COREBRANCH} COREBRANCH

setup_stage ${STAGEDIR}
setup_base ${STAGEDIR}
setup_chroot ${STAGEDIR}

extract_packages ${STAGEDIR}
remove_packages ${STAGEDIR} ${@}
install_packages ${STAGEDIR} pkg git
lock_packages ${STAGEDIR}

if [ -n "${COREVERSION}" ]; then
	CORE_PKGVERSION="CORE_PKGVERSION=${COREVERSION}"
fi

for BRANCH in ${EXTRABRANCH} ${COREBRANCH}; do
	setup_copy ${STAGEDIR} ${COREDIR}
	git_reset ${STAGEDIR}${COREDIR} ${BRANCH}

	CORE_ARGS="CORE_ARCH=${PRODUCT_ARCH} ${COREENV}"
	if [ ${BRANCH} = ${COREBRANCH} ]; then
		CORE_ARGS="${CORE_ARGS} ${CORE_PKGVERSION}"
	fi

	CORE_NAME=$(make -C ${STAGEDIR}${COREDIR} ${CORE_ARGS} -v CORE_NAME)
	CORE_DEPS=$(make -C ${STAGEDIR}${COREDIR} ${CORE_ARGS} -v CORE_DEPENDS)
	CORE_VERS=$(make -C ${STAGEDIR}${COREDIR} ${CORE_ARGS} -v CORE_PKGVERSION)

	for REMOVED in ${@}; do
		if [ ${REMOVED} = ${CORE_NAME} ]; then
			# make sure a subsequent build of the
			# same package goes through by removing
			# it while it may have been rebuilt on
			# another branch
			remove_packages ${STAGEDIR} ${REMOVED}
		fi
	done

	if search_packages ${STAGEDIR} ${CORE_NAME} ${CORE_VERS} ${BRANCH}; then
		# already built
		continue
	fi

	install_packages ${STAGEDIR} ${CORE_DEPS}
	custom_packages ${STAGEDIR} ${COREDIR} \
	    "${CORE_ARGS}" ${CORE_NAME} ${CORE_VERS}
done

bundle_packages ${STAGEDIR} ${SELF}
