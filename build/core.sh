#!/bin/sh

# Copyright (c) 2014-2019 Franco Fichtner <franco@opnsense.org>
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

check_packages ${SELF} ${@}

git_branch ${COREDIR} ${COREBRANCH} COREBRANCH

setup_stage ${STAGEDIR}
setup_base ${STAGEDIR}
setup_chroot ${STAGEDIR}

extract_packages ${STAGEDIR}
remove_packages ${STAGEDIR} ${@}
install_packages ${STAGEDIR} pkg git
lock_packages ${STAGEDIR}

for BRANCH in ${DEVELBRANCH} ${COREBRANCH}; do
	setup_copy ${STAGEDIR} ${COREDIR}
	git_reset ${STAGEDIR}${COREDIR} ${BRANCH}

	CORE_ARGS="CORE_ARCH=${PRODUCT_ARCH} ${COREENV}"

	CORE_NAME=$(make -C ${STAGEDIR}${COREDIR} ${CORE_ARGS} name)
	CORE_DEPS=$(make -C ${STAGEDIR}${COREDIR} ${CORE_ARGS} depends)

	if search_packages ${STAGEDIR} ${CORE_NAME}; then
		# already built
		continue
	fi

	install_packages ${STAGEDIR} ${CORE_DEPS}
	custom_packages ${STAGEDIR} ${COREDIR} "${CORE_ARGS}"
done

bundle_packages ${STAGEDIR} ${SELF}
