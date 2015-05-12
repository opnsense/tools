About the OPNsense tools
========================

In conjunction with src.git, ports.git and core.git they create
sets, packages and images for the OPNsense project.  The license
is a standard BSD 2-Clause as reproduced here for your convenience:

    Copyright (c) 2014-2015 Franco Fichtner <franco@opnsense.org>
    Copyright (c) 2004-2011 Scott Ullrich <sullrich@gmail.com>
    Copyright (c) 2005 Poul-Henning Kamp <phk@FreeBSD.org>
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions
    are met:
    
    1. Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.
    
    2. Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in the
       documentation and/or other materials provided with the distribution.
    
    THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
    ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
    IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
    ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
    FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
    DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
    OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
    HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
    LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
    OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
    SUCH DAMAGE.

Setting up a build system
=========================

Install FreeBSD 10.1 (i386 or amd64 depending on your target arch)
RELEASE on a machine with at least 10GB of hard disk (UFS works better
than ZFS) and at least 2GB of RAM.  All tasks require a root user.  Do
the following to grab the repositories (overwriting standard ports and
src):

    # pkg install git
    # cd /usr
    # rm -rf src ports
    # git clone https://github.com/opnsense/ports
    # git clone https://github.com/opnsense/tools
    # git clone https://github.com/opnsense/core
    # git clone https://github.com/opnsense/src

Running the actual build
========================

The build is broken down into individual stages: base,
kernel and ports can be built separately and repeatedly
without affecting the others.  All stages can be reinvoked
and continue building without cleaning the previous progress.
A final stage assembles all three stages into a target image.

Go to the build directory:

    # cd /usr/tools/build

Setup an additional build configuration (or skip to use the defaults):

    # ./configure.sh -f flavour -n name -v version

Available options are:

* flavour: "OpenSSL" (default), "LibreSSL"
* version: a version tag (if applicable)
* name: "OPNsense" (default)

Build the userland binaries, bootloader and administrative
files:

    # ./base.sh

Build the kernel and loadable kernel modules:

    # ./kernel.sh

Build all the third-party ports:

    # ./ports.sh

Wrap up our core as a package:

    # ./core.sh

A cdrom live image is created using:

    # ./iso.sh

A memstick image for VGA and serial is created using:

    # ./memstick.sh

A direct disk image in NanoBSD style is created using:

    # ./nano.sh

Some more random information
============================

Before building images, you can run the regression tests
to check the integrity of your core.git modifications plus
generate output for the style checker:

    # cd /usr/tools/build && ./regress.sh

The OPNsense core package can then be rebuilt on its own via:

    # cd /usr/tools/build && ./core.sh

For very fast ports rebuilding of already installed packages
the following works:

    # cd /usr/tools/build && ./ports.sh [packagename ...]

Package sets (may be signed depending on whether the key is
found under /root) ready for web server deployment are automatically
generated and modified by ports.sh and core.sh.

Release sets can be built using:

    # cd /usr/tools/build && ./release.sh [version]

Kernel, base, packages and release sets are stored under /tmp/sets

All final images are stored under /tmp/images

A couple of build machine cleanup helpers are available
via the clean script:

    # cd /usr/tools/build && ./clean.sh what ...

Available options are:

* env: scrub the build config and use defaults
* images: remove all available images
* obj: reset the kernel/base build directory
* sets: remove all available sets
* stage: reset the main staging area
