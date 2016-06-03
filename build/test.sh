#!/bin/sh

# Copyright (c) 2014 Franco Fichtner <franco@opnsense.org>
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

. ./common.sh && $(${SCRUB_ARGS})

setup_stage ${STAGEDIR}
setup_base ${STAGEDIR}
setup_clone ${STAGEDIR} ${COREDIR}
setup_clone ${STAGEDIR} ${PLUGINSDIR}
setup_chroot ${STAGEDIR}

extract_packages ${STAGEDIR}
install_packages ${STAGEDIR} ${PRODUCT_TYPE} pear-PHP_CodeSniffer phpunit
# don't want to deinstall in case of testing...

# install all plugins, see if files clash
# between those and PRODUCT_TYPE package
for PKGFILE in $({
	cd ${STAGEDIR}
	# ospriv- means development so is ok to break
	# (left in here for manual testing workflow)
	#find .${PACKAGESDIR}/All -name "ospriv-*.txz"
	find .${PACKAGESDIR}/All -name "os-*.txz"
}); do
	pkg -c ${BASEDIR} add ${PKGFILE}
done

echo ">>> Running ${PLUGINSDIR} test suite..."
chroot ${STAGEDIR} /bin/sh -es <<EOF
make -C${PLUGINSDIR} lint
EOF

echo ">>> Running ${COREDIR} test suite..."

chroot ${STAGEDIR} /bin/sh -es <<EOF
make -C${COREDIR} setup
make -C${COREDIR} lint
make -C${COREDIR} health
make -C${COREDIR} style
EOF
