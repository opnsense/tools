#!/bin/sh

# Copyright (c) 2014-2018 Franco Fichtner <franco@opnsense.org>
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

SELF=test

. ./common.sh

git_branch ${PLUGINSDIR} ${PLUGINSBRANCH} PLUGINSBRANCH
git_branch ${COREDIR} ${COREBRANCH} COREBRANCH

setup_stage ${STAGEDIR}
setup_base ${STAGEDIR}
setup_clone ${STAGEDIR} ${COREDIR}
setup_clone ${STAGEDIR} ${PLUGINSDIR}
setup_chroot ${STAGEDIR}

extract_packages ${STAGEDIR}
install_packages ${STAGEDIR} ${PRODUCT_CORE} os-debug${PRODUCT_SUFFIX}
lock_packages ${STAGEDIR}

# XXX plugins have conflicts, cannot install all for following check

echo ">>> Running packages test suite..."
chroot ${STAGEDIR} /bin/sh -es <<EOF
pkg check -da
pkg check -sa
EOF

# XXX make test also exists for plugins, but requires installation

echo ">>> Running ${PLUGINSDIR} test suite..."
chroot ${STAGEDIR} /bin/sh -es <<EOF
make -C${PLUGINSDIR} lint
make -C${PLUGINSDIR} style
EOF

echo ">>> Running ${COREDIR} test suite..."
chroot ${STAGEDIR} /bin/sh -es <<EOF
make -C${COREDIR} lint
make -C${COREDIR} style
# XXX does not work well with PRODUCT_SUFFIX set
make -C${COREDIR} test
EOF
