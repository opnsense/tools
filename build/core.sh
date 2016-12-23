#!/bin/sh

# Copyright (c) 2014-2016 Franco Fichtner <franco@opnsense.org>
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

. ./common.sh && $(${SCRUB_ARGS})

. ${CONFIGDIR}/core.conf

check_packages ${SELF} ${@}

setup_stage ${STAGEDIR}
setup_base ${STAGEDIR}
setup_chroot ${STAGEDIR}

extract_packages ${STAGEDIR}
# register persistent packages to avoid bouncing
install_packages ${STAGEDIR} pkg git gettext-tools
lock_packages ${STAGEDIR}

if [ -z "${*}" ]; then
	setup_clone ${STAGEDIR} ${COREDIR}
	CORE_TAGS="bogus"
else
	CORE_TAGS="${*}"
fi

for CORE_TAG in ${CORE_TAGS}; do
	CORE_ARGS="CORE_NAME=${CORE_NAME} CORE_FAMILY=${CORE_FAMILY}"

	if [ -n "${*}" ]; then
		setup_copy ${STAGEDIR} ${COREDIR}
		git_checkout ${STAGEDIR}${COREDIR} ${CORE_TAG}
		git_describe ${STAGEDIR}${COREDIR} ${CORE_TAG}
		if [ "${REPO_REFTYPE}" != tag ]; then
			CORE_NAME=$(make -C ${STAGEDIR}${COREDIR} name)
			CORE_ARGS=
		fi
	fi

	CORE_ARGS="CORE_ARCH=${CORE_ARCH} ${CORE_ARGS}"
	CORE_DEPS=$(make -C ${STAGEDIR}${COREDIR} ${CORE_ARGS} depends)

	remove_packages ${STAGEDIR} ${CORE_NAME}
	install_packages ${STAGEDIR} ${CORE_DEPS}
	custom_packages ${STAGEDIR} ${COREDIR} "${CORE_ARGS}"
done

bundle_packages ${STAGEDIR} ${SELF}
