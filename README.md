About the OPNsense tools
========================

In conjunction with src.git, ports.git, core.git and plugins.git they
create sets, packages and images for the OPNsense project.

Setting up a build system
=========================

Install [FreeBSD](https://www.freebsd.org/) 11.1-RELEASE (i386 or amd64 depending on your target)
on a machine with at least 25GB of hard disk (UFS works better than ZFS)
and at least 4GB of RAM to successfully build all standard images.  All
tasks require a root user.  Do the following to grab the repositories
(overwriting standard ports and src):

    # pkg install git
    # cd /usr
    # git clone https://github.com/opnsense/tools
    # cd tools
    # make update

TL;DR
=====

    # make dvd

If successful, a dvd image can be found under:

    # make print-IMAGESDIR

Detailed build steps and options
================================

How to specify build options on the command line
------------------------------------------------

The build is broken down into individual stages: base,
kernel and ports can be built separately and repeatedly
without affecting the others.  All stages can be reinvoked
and continue building without cleaning the previous progress.
A final stage assembles all three stages into a target image.

All build steps are invoked via make(1):

    # make step OPTION="value"

Available early build options are:

* CONFIG: 	reads the below from the specified file
* SETTINGS:	the name of the requested config directory

Available build options are:

* ADDITIONS:	a list of packages/plugins to add to images
* ARCH:		the target architecture if not native
* DEVICE:	loads device-specific modifications, e.g. "a10" (default)
* FLAVOUR:	"OpenSSL" (default), "LibreSSL", "Base"
* KERNEL:	the kernel config to use, e.g. SMP (default)
* MIRRORS:	a list of mirrors to prefetch sets from
* NAME:		"OPNsense" (default)
* PRIVKEY:	the private key for signing sets
* PUBKEY:	the public key for signing sets
* SPEED:	serial speed, e.g. "115200" (default)
* TYPE:         the base name of the top package to be installed
* SUFFIX:	the suffix of top package name (empty, "-devel")
* UEFI:		"yes" for amd64 hybrid images with optional UEFI boot
* VERSION:	a version tag (if applicable)

How to specify build options via configuration file
---------------------------------------------------

The default CONFIG file is under "config/SETTINGS/build.conf".
It can also be overrided by "/dev/null".

How to run individual or composite build steps
----------------------------------------------

Kernel, base, packages and release sets are stored under:

    # make print-SETSDIR

All final images are stored under:

    # make print-IMAGESDIR

Build the userland binaries, bootloader and administrative files:

    # make base

Build the kernel and loadable kernel modules:

    # make kernel

Build all the third-party ports:

    # make ports

Build additional plugins if needed:

    # make plugins

Wrap up our core as a package:

    # make core

A dvd live image is created using:

    # make dvd

A serial memstick live image is created using:

    # make serial

A vga memstick live image is created using:

    # make vga

A flash card full disk image is created using:

    # make nano

A virtual machine full disk image is created using:

    # make vm

Release sets can be built using:

    # make release VERSION=product.version.number_revision

Cross-building for other architecures
-------------------------------------

This feature is currently experimental and tailored
for use with the Raspberry Pi 2.  It requires installation
of the qemu package for user mode emulation:

    # pkg install qemu-user-static

A cross-build on the operating system sources is
executed by specifying the target architecture and
custom kernel:

    # make base kernel ARCH=arm:armv6 KERNEL=SMP-RPI2

In order to speed up building of using an emulated
packages build, the xtools set can be created like so:

    # make xtools ARCH=arm:armv6

The xtools set is then used during the packages build
similar to the distfiles set.

    # make packages ARCH=arm:armv6

The image will also require a matching u-boot package:

    # pkg install u-boot-rpi2

The final image is built using:

    # make arm-<size> ARCH=arm:armv6

About other scripts and tweaks
==============================

Device-specific settings
------------------------

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
dvd, nano, serial, vga and vm.  Device-specific hooks
are loaded after config-specific hooks and both of them
can coexist in a given build.

Updating the code repositories
------------------------------

Updating all or individual repositories can be done as follows:

    # make update[-<repo1>[,...]]

Available update options are: core, plugins, ports, src, tools

Regression tests
----------------

Before building images, you can run the regression tests
to check the integrity of your core.git modifications plus
generate output for the style checker:

    # make test

Advanced package builds
-----------------------

For very fast ports rebuilding of already installed packages
the following works:

    # make ports-<packagename>[,...]

For even faster ports building it may be of use to cache all
distribution files before running the actual build:

    # make distfiles

Core packages can be batch-built using:

    # make core-<repo_branch_or_tag>[,...]

Package sets ready for web server deployment are automatically
generated and modified by ports.sh, plugins.sh and core.sh.
If signing keys are available, the packages set will be signed
twice, first embedded into repository metadata (inside) and
then again as a flat file (outside) to ensure integrity.

Acquiring precompiled sets from the mirrors
-------------------------------------------

Compiled sets can be prefetched from a mirror if they exist,
while removing any previously available set:

    # make prefetch-<option>[,...] VERSION=version.to.prefetch

Available prefetch options are:

* base:		prefetch the base set
* kernel:	prefetch the kernel set
* kernel-dbg:	prefetch the debug kernel set (if available)
* packages:	prefetch the packages set

Using signatures to verify integrity
------------------------------------

Signing for all sets can be redone or applied to a previous run
that did not sign by invoking:

    # make sign

A verification of all available set signatures is done via:

    # make verify

Nano image size adjustment
--------------------------

Nano images can be adjusted in size using an argument as follows:

    # make nano-<size>

Virtual machine images
----------------------

Virtual machine images come in varying disk formats and sizes.
For this reason they are not included in our binary releases.
The default format is vmdk with 20G and 1G swap.  If you want
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

Clearing individual build step progress
---------------------------------------

A couple of build machine cleanup helpers are available
via the clean script:

    # make clean-<option>[,...]

Available clean options are:

* arm:		remove arm image
* base:		remove base set
* distfiles:	remove distfiles set
* dvd:		remove dvd image
* core:		remove core from packages set
* images:	remove all images
* kernel:	remove kernel set
* logs:		remove all logs
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

How the port tree is synced with its upstream repository
--------------------------------------------------------

The ports tree has a few of our modifications and is sometimes a
bit ahead of HardenedBSD.  In order to keep the local changes, a
skimming script is used to review and copy upstream changes:

    # make skim[-<option>]

Available options are:

* used:		review and copy upstream changes
* unused:	copy unused upstream changes
* (none):	all of the above

Rebasing the file lists for the base sets
-----------------------------------------

In case base files changed, the base package list and obsoleted
files need to be regenerated.  This is done using:

    # make rebase

Switching to the build jail for inspection
------------------------------------------

Shall any debugging be needed inside the build jail, the following
command will use chroot(8) to enter the active build jail:

    # make chroot[-<subdir>]

Boot images in the native bhyve(8) hypervisor
---------------------------------------------

There's also the posh way to boot a final image using bhyve(8):

    # make boot-<image>

Please note that the system does not have working networking after
bootup and login is only possible via the Nano and Serial images.

Reading and modifying version numbers of build sets and images
--------------------------------------------------------------

Normally the build scripts will pick up version numbers based
on commit tags or given version tags or a date-type string.
Should it not fit your needs, you can change the name using:

    # make rename-<set>[,<another_set>] VERSION=<new_name>

The available targets are: base, distfiles, dvd, kernel, nano,
packages, serial, vga and vm.

The current state or a tagged state of required build repositories
on the system can be printed using:

    # make info[-<version>]

Last but not least, in case build variables needs to be inspected,
they can be printed selectively using:

    # make print-<variable1>[,<variable2>]

Composite build steps
---------------------

Build steps are pinned to a particular crypto flavour, but if OpenSSL
and LibreSSL packages are both required they can be batch-built using:

    # make batch-<step>[,<option>[,...]]

A fully contained nightly build for the system is invoked using:

    # make nightly

Nightly builds are the only builds that write and archive logs under:

    # make print-LOGSDIR

with ./latest pointing to the last nightly build run.  Older logs are
archived and available for a number of runs for retrospective analysis.

Last but not least, a refresh of OPNsense core and plugins on package
sets is invoked using:

    # make refresh

It will flush all previous packages except for ports, rebuild core and
plugins and sign the sets if enabled.  It is used to issue hotfixes.
