#!/bin/sh

# Copyright (c) 2014-2015 Franco Fichtner <franco@opnsense.org>
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

. ./common.sh && $(${SCRUB_ARGS})

sh ./clean.sh base

git_describe ${SRCDIR}

MAKEARGS="SRCCONF=${CONFIGDIR}/src.conf COMPILER_TYPE=clang __MAKE_CONF="
ENVFILTER="env -i USER=${USER} LOGNAME=${LOGNAME} HOME=${HOME} \
SHELL=${SHELL} BLOCKSIZE=${BLOCKSIZE} MAIL=${MAIL} PATH=${PATH} \
TERM=${TERM} HOSTTYPE=${HOSTTYPE} VENDOR=${VENDOR} OSTYPE=${OSTYPE} \
MACHTYPE=${MACHTYPE} PWD=${PWD} GROUP=${GROUP} HOST=${HOST} \
EDITOR=${EDITOR} PAGER=${PAGER}"

${ENVFILTER} make -C${SRCDIR} -j${CPUS} buildworld ${MAKEARGS} NO_CLEAN=yes
${ENVFILTER} make -C${SRCDIR}/release obj ${MAKEARGS}
${ENVFILTER} make -C${SRCDIR}/release base.txz ${MAKEARGS}

BASESET=${SETSDIR}/base-${REPO_VERSION}-${ARCH}

mv $(make -C${SRCDIR}/release -V .OBJDIR)/base.txz ${BASESET}.txz

echo -n "Generating obsolete file list... "

tar -tf ${BASESET}.txz | \
    sed -e 's/^\.//g' -e '/\/$/d' | sort > /tmp/setdiff.new.${$}

: > /tmp/setdiff.old.${$}
if [ -s ${CONFIGDIR}/plist.base.${ARCH} ]; then
	cat ${CONFIGDIR}/plist.base.${ARCH} | \
	    sed -e 's/^\.//g' -e '/\/$/d' | sort > /tmp/setdiff.old.${$}
fi

: > /tmp/setdiff.tmp.${$}
if [ -s ${CONFIGDIR}/plist.obsolete.${ARCH} ]; then
	diff -u ${CONFIGDIR}/plist.obsolete.${ARCH} \
	    /tmp/setdiff.new.${$} | grep '^-/' | \
	    cut -b 2- > /tmp/setdiff.tmp.${$}
fi

(cat /tmp/setdiff.tmp.${$}; diff -u /tmp/setdiff.old.${$} \
    /tmp/setdiff.new.${$} | grep '^-/' | cut -b 2-) | \
    sort -u > ${BASESET}.obsolete

rm -f /tmp/setdiff.*

echo "done"

echo -n "Signing sets (if applicable)... "

generate_signature ${BASESET}.txz
generate_signature ${BASESET}.obsolete

echo "done"
