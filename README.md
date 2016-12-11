About the OPNsense tools
========================

In conjunction with src.git, ports.git, core.git and plugins.git they
create sets, packages and images for the OPNsense project.  The license
is a standard BSD 2-Clause as reproduced here for your convenience:

    Copyright (c) 2014-2016 Franco Fichtner <franco@opnsense.org>
    Copyright (c) 2004-2011 Scott Ullrich <sullrich@gmail.com>
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

Install FreeBSD 10.3-RELEASE (i386 or amd64 depending on your target arch)
on a machine with at least 25GB of hard disk (UFS works better than ZFS)
and at least 6GB of RAM to successfully build all standard images.  All
tasks require a root user.  Do the following to grab the repositories
(overwriting standard ports and src):

    # pkg install git
    # cd /usr
    # rm -rf src ports
    # git clone https://github.com/opnsense/plugins
    # git clone https://github.com/opnsense/ports
    # git clone https://github.com/opnsense/tools
    # git clone https://github.com/opnsense/core
    # git clone https://github.com/opnsense/src
    # cd tools

TL;DR
=====

    # make cdrom

If successful, a cdrom image can be found here: /tmp/images

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

* ARCH:		the target architecture if not native
* CONFIG: 	reads the below from the specified file
* DEVICE:	loads device-specific modifications, e.g. "a10" (default)
* FLAVOUR:	"OpenSSL" (default), "LibreSSL", "Base"
* MIRRORS:	a list of mirrors to prefetch sets from
* NAME:		"OPNsense" (default)
* PRIVKEY:	the private key for signing sets
* PUBKEY:	the public key for signing sets
* SETTINGS:	the name of the selected settings in config/
* SPEED:	serial speed, e.g. "115200" (default)
* TYPE:         the base name of the top package to be installed
* SUFFIX:	the suffix of top package name (empty, "-stable", "-devel")
* UEFI:		"yes" for amd64 hybrid images with optional UEFI boot
* VERSION:	a version tag (if applicable)

Build the userland binaries, bootloader and administrative
files:

    # make base

Build the kernel and loadable kernel modules:

    # make kernel

Build all the third-party ports:

    # make ports

Build additional plugins if needed:

    # make plugins

Wrap up our core as a package:

    # make core

A cdrom live image is created using:

    # make cdrom

A serial memstick image is created using:

    # make serial

A vga memstick image is created using:

    # make vga

A flash card disk image is created using:

    # make nano

A virtual machine disk image is created using:

    # make vm

Cross-building for other architecures
=====================================

This feature is currently experimental.  It requires
to install a qemu package for user mode emulation:

    # pkg install qemu-user-static

The current target is the Raspberry Pi 1 / 2 using the
option ARCH=arm:armv6 and is supposed to run best on
i386 for a matching 32 bit size.

In order to speed up building of an emulated build,
the xtools set can be build:

    # make xtools ARCH=arm:armv6

The xtools set works similar to the distfiles set.

About other scripts and tweaks
==============================

Device-specific settings can be found and added in the
device/ directory.  Of special interest are hooks into
the build process for required non-default settings for
image builds.  The .conf files are shell scrips that can
define hooks in the form of e.g.:

    serial_hook()
    {
        # ${1} is the target file system root
        touch ${1}/my_custom_file
    }

These hooks are available for all image types, namely
cdrom, nano, serial, vga and vm.  Device-specific hooks
are loaded after config-specific hooks and both of them
can coexist in a given build.

Before building images, you can run the regression tests
to check the integrity of your core.git modifications plus
generate output for the style checker:

    # make test

For very fast ports rebuilding of already installed packages
the following works:

    # make ports-<packagename>[,...]

For even faster ports building it may be of use to cache all
distribution files before running the actual build:

    # make distfiles

Compiled sets can be prefetched from a mirror, while removing
any previously available set:

    # make prefetch-<option>[,...] VERSION=version.to.prefetch

Available prefetch options are:

* base:		prefetch the base set
* kernel:	prefetch the kernel set
* packages:	prefetch the packages set

Core packages (pristine copies) can be batch-built using:

    # make core-<repo_branch_or_tag>[,...]

Package sets ready for web server deployment are automatically
generated and modified by ports.sh, plugins.sh and core.sh.
If signing keys are available, the packages set will be signed
twice, first embedded into repository metadata (inside) and
then again as a flat file (outside) to ensure integrity.

Signing for all sets can be redone or applied to a previous run
that did not sign by invoking:

    # make sign

A verification of all available set signatures is done via:

    # make verify

Nano images can be adjusted in size using an argument as follows:

    # make nano-<size>

Virtual machine images come in varying disk formats and sizes.
The default format is vmdk with 20G and 1G swap. If you want
to change that you can manually alter the invoke using:

    # make vm-<format>[,<size>[,<swap>]]

Available virtual machine disk formats are:

* qcow:		Qemu, KVM (legacy format)
* qcow2:	Qemu, KVM (not backwards-compatible)
* raw:		Unformatted (sector by sector)
* vhd:		VirtualPC, Hyper-V, Xen (dynamic size)
* vhdf:		Azure, VirtualPC, Hyper-V, Xen (fixed size)
* vmdk:		VMWare, VirtualBox (dynamic size)

The swap argument is either its size or set to "off" to disable.

Release sets can be built using:

    # make release VERSION=product.version.number_revision

Kernel, base, packages and release sets are stored under /tmp/sets

All final images are stored under /tmp/images

A couple of build machine cleanup helpers are available
via the clean script:

    # make clean-<option>[,...]

Available clean options are:

* base:		remove base set
* distfiles:	remove distfiles set
* cdrom:	remove cdrom image
* core:		remove core from packages set
* images:	remove all images
* kernel:	remove kernel set
* nano:		remove nano image
* obj:		remove all object directories
* packages:	remove packages set
* plugins:	remove plugins from packages set
* ports:	alias for "packages" option
* release:	remove release set
* serial:	remove serial image
* sets:		remove all sets
* src:		reset kernel/base build directory
* stage:	reset main staging area
* vga:		remove vga image
* vm:		remove vm image
* xtools:	remove xtools set

The ports tree has a few of our modifications and is sometimes a
bit ahead of FreeBSD.  In order to keep the local changes, a skimming
script is used to review and copy upstream changes:

    # make skim[-<option>]

Available options are:

* used:		review and copy upstream changes
* unused:	copy unused upstream changes
* (none):	all of the above

In case a release was wrapped up, the base package list and obsoleted
files need to be regenerated.  This is done using:

    # make rebase

Shall any debugging be needed inside the build jail, the following
command will use chroot(8) to enter the active build jail:

    # make chroot[-<subdir>]

There's also the posh way to boot a final image using bhyve(8):

    # make boot-<image>

Normally the build scripts will pick up version numbers based
on commit tags or given version tags or a date-type string.
Should it not fit your needs, you can change the name using:

    # make rename-<set>[,<another_set>] VERSION=<new_name>

The available targets are: base, kernel and package.

Last but not least, in case build variables needs to be inspected,
they can be printed selectively using:

    # make print-<variable1>[,<variable2>]
