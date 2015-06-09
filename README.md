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
    # cd tools

TL;DR
=====

    # make everything

If successful, images can be found here: /tmp/images

Detailed build steps and options
================================

The build is broken down into individual stages: base,
kernel and ports can be built separately and repeatedly
without affecting the others.  All stages can be reinvoked
and continue building without cleaning the previous progress.
A final stage assembles all three stages into a target image.

All build steps are invoked via make(1):

    # make step OPTION="value"

Available build options are:

* NAME:		"OPNsense" (default)
* FLAVOUR:	"OpenSSL" (default), "LibreSSL"
* VERSION:	a version tag (if applicable)
* CONFIG: 	reads the above from the specified file

Build the userland binaries, bootloader and administrative
files:

    # make base

Build the kernel and loadable kernel modules:

    # make kernel

Build all the third-party ports:

    # make ports

Wrap up our core as a package:

    # make core

A cdrom live image is created using:

    # make iso

A memstick image for VGA and serial is created using:

    # make memstick

A direct disk image in NanoBSD style is created using:

    # make nano

About other scripts and tweaks
==============================

A known state can be checked out, removing all unwanted files
from the repository, fetching all remote updates, via:

    # make checkout[-<repo_branch_or_tag>]

Before building images, you can run the regression tests
to check the integrity of your core.git modifications plus
generate output for the style checker:

    # make regress

For very fast ports rebuilding of already installed packages
the following works:

    # make ports-<packagename>[,...]

Package sets (may be signed depending on whether the key is
found under /root) ready for web server deployment are automatically
generated and modified by ports.sh and core.sh.

Release sets can be built using:

    # make release

Kernel, base, packages and release sets are stored under /tmp/sets

All final images are stored under /tmp/images

A couple of build machine cleanup helpers are available
via the clean script:

    # make clean-<option>[,...]

Available options are:

* images:	remove all available images
* obj:		reset the kernel/base build directory
* kernel:	remove the kernel set
* base:		remove the base set
* packages:	remove the packages set
* release:	remove the release set
* stage:	reset the main staging area

The ports tree has a few of our modifications and is sometimes a
bit ahead of FreeBSD.  In order to keep the local changes, a skimming
script is used to review and copy upstream changes:

    # make skim[-<option>]

Available options are:

* used:		review and copy upstream changes
* unused:	copy unused upstream changes
* (none):	all of the above
