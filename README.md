About the OPNsense tools
========================

In conjunction with src.git, ports.git, core.git and plugins.git they
create sets, packages and images for the OPNsense project.

Setting up a build system
=========================

Install [FreeBSD](https://www.freebsd.org/) 13.1-RELEASE for amd64
on a machine with at least 25GB of hard disk (UFS works better than ZFS)
and at least 4GB of RAM to successfully build all standard images.
All tasks require a root user.  Do the following to grab the repositories
(overwriting standard ports and src):

    # pkg install git
    # cd /usr
    # git clone https://github.com/opnsense/tools
    # cd tools

*pkg* Shenanigans
-----------------

Upstream keeps making incompatible changes to ``pkg`` which causes build
failures.  In order to work around this problem you must use the OPNsense
version of pkg, not the FreeBSD version of pkg.  This will require some
non-standard setup to accomplish.

This is necessary because OPNsense builds within a jail and most but not
all operations happen with the jails version of `pkg`. There are some aspects
of the build process that operate outside the jail and those steps require
interoperability between the base pkg and the jail pkg.  To enable this
compatibility you will need to use the OPNsense package repositories instead
of the FreeBSD ones.  The fix for this is a make target, so you can simply
issue the following to fix the pkg version.  **WARNING:  This step will
uninstall all existing packages and destroy the package database directory.
If this machine is used for any other purposes other than building OPNsense
this will likely break your machine.**

    # make fix

Resuming Setup
--------------

Now we can resume the build with the proper `pkg` having been installed:

    # make update

Note that the OPNsense repositories can also be setup in a non-/usr directory
by setting ROOTDIR.  For example:

    # mkdir -p /tmp/opnsense
    # cd /tmp/opnsense
    # git clone https://github.com/opnsense/tools
    # cd tools
    # env ROOTDIR=/tmp/opnsense make update

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
kernel, ports, plugins and core can be built separately and
repeatedly without affecting the other stages.  All stages
can be reinvoked and continue building without cleaning the
previous progress.  A final stage assembles all five stages
into a target image.

All build steps are invoked via make(1):

    # make step OPTION="value"

Available early build options are:

* SETTINGS:	the name of the requested local configuration
* CONFIGDIR:	read configuration from other directory and override SETTINGS

Available build options are:

* ABI:		a custom ABI (defaults to SETTINGS)
* ADDITIONS:	a list of packages/plugins to add to images
* ARCH:		the target architecture if not native
* COMSPEED:	serial speed, e.g. "115200" (default)
* DEBUG:	build a debug kernel with additional object information
* DEVICE:	loads device-specific modifications, e.g. "A10" (default)
* FLAVOUR:	"OpenSSL" (default), "LibreSSL", "Base"
* KERNEL:	the kernel config to use, e.g. SMP (default)
* MIRRORS:	a list of mirrors to prefetch sets from
* NAME:		"OPNsense" (default)
* PRIVKEY:	the private key for signing sets
* PUBKEY:	the public key for signing sets
* SUFFIX:	the suffix of top package name (default is empty)
* TYPE:		the base name of the top package to be installed
* UEFI:		use amd64 hybrid images for said images, e.g. "vga vm"
* VERSION:	a version tag (if applicable)
* ZFS:		ZFS pool name to create for VM images, e.g. "zpool"

How to specify build options via configuration file
---------------------------------------------------

The configuration file is required at "CONFIGDIR/build.conf".
Its contents can be modified to adapt a non-standard build environment
and to avoid excessive Makefile arguments.

A local override exists as "CONFIGDIR/build.conf.local" and is
parsed first to allow more flexible overrides.  Use with care.

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

A special embedded device image based on vm variety:

    # make factory

Release sets can be built as follows although the result is
an unpredictable set of images depending on the previous
build states:

    # make release

However, the release target is necessary for the following
target which includes sanity checks, proper clearing of the
images directory and core package version alignment:

    # make distribution

Cross-building for other architecures
-------------------------------------

This feature is currently experimental and requires installation
of packages for cross building / user mode emulation and additional
boot files to be installed as prompted by the build system.

A cross-build on the operating system sources is executed by
specifying the target architecture and custom kernel:

    # make base kernel DEVICE=BANANAPI

In order to speed up building of using an emulated packages build,
the xtools set can be created like so:

    # make xtools DEVICE=BANANAPI

The xtools set is then used during the packages build similar to
the distfiles set.

    # make packages DEVICE=BANANAPI

The final image is built using:

    # make arm-<size> DEVICE=BANANAPI

Currently available device are: BANANAPI and RPI2.

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

Available update options are: core, plugins, ports, portsref, src, tools

Regression tests and ports audit
--------------------------------

Before building images, you can run the regression tests
to check the integrity of your core.git modifications plus
generate output for the style checker:

    # make test

To check the binary packages from ports against the upstream
vulnerability database run the following:

    # make audit

Advanced package builds
-----------------------

Package sets ready for web server deployment are automatically
generated and modified by ports, plugins and core setps.  The
build automatically caches temporary build dependencies to avoid
spurious rebuilds.  These packages are later discarded to provide
a slim runtime set only.

If signing keys are available, the packages set will be signed
twice, first embedded into repository metadata (inside) and
then again as a flat file (outside) to ensure integrity.

For faster ports building it may be of use to cache all distribution
files before running the actual build:

    # make distfiles

For targeted rebuilding of already built packages the following
works:

    # make ports-<packagename>[,...]
    # make plugins-<packagename>[,...]
    # make core-<packagename>[,...]

Please note that reissuing ports builds will clear plugins and
core progress.  However, following option apply to PORTSENV:

* BATCH=no	Developer mode with shell after each build failure
* DEPEND=no	Do not tamper with plugins or core packages
* PRUNE=no	Do not check ports integrity prior to rebuild

The defaults for these ports options are set to "yes".  A sample
invoke is as follows:

    # make ports-curl PORTSENV="DEPEND=no PRUNE=no"

Both ports and plugins builds allow to override the current list
derived from their respective configuration files, i.e.:

    # make ports PORTSLIST="security/openssl"
    # make plugins PLUGINSLIST="devel/debug"

Acquiring precompiled sets from the mirrors or another local direcory
---------------------------------------------------------------------

Compiled sets can be prefetched from a mirror if they exist,
while removing any previously available set:

    # make prefetch-<option>[,...] [VERSION=<full_version>]

If another build configuration is used locally that is compatible,
the sets can be cloned from there as well:

    # make clone-<option>[,...] TO=<major_version>

Available prefetch or clone options are:

* base:		select matching base set
* distfiles:	select matching distfiles set (clone only)
* kernel:	select matching kernel set
* packages:	select matching packages set

Using signatures to verify integrity
------------------------------------

Signing for all sets can be redone or applied to a previous run
that did not sign by invoking:

    # make sign-base,kernel,packages

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
bit ahead of FreeBSD.  In order to keep the local changes, a
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

Please note that login is only possible via the Nano and Serial images.

Booting VM images will not work for types other than "raw".

Generating a make.conf for use in running OPNsense
--------------------------------------------------

A ports tree in a running OPNsense can be used to build packages
not published on the mirrors.  To generate the make.conf contents
for standalone use on the host use:

    # make make.conf

Reading and modifying version numbers of build sets and images
--------------------------------------------------------------

Normally the build scripts will pick up version numbers based
on commit tags or given version tags or a date-type string.
Should it not fit your needs, you can change the name using:

    # make rename-<set>[,<another_set>] VERSION=<new_name>

The available targets are: base, distfiles, dvd, kernel, nano,
packages, serial, vga and vm.

The current state of the associated build repositories checked
out on the system can be printed using:

    # make info

Repositories that have signing keys can show the current
fingerprint using:

    # make fingerprint

Last but not least, in case build variables needs to be inspected,
they can be printed selectively using:

    # make print-<variable1>[,<variable2>]

Compressing images
------------------

Images are compressed using bzip2(1) for distribution.  This can
be invoked manually using:

    # make compress-<image1>[,<image2>]

Composite build steps
---------------------

Build steps are pinned to a particular crypto flavour, but if OpenSSL
and LibreSSL packages are both required they can be batch-built using:

    # make batch-<step>[,<option>[,...]]

A fully contained nightly build for the system is invoked using:

    # make nightly

To allow the nightly build to build both release and development packages
use:

    # make nightly EXTRABRANCH=master

Nightly builds are the only builds that write and archive logs under:

    # make print-LOGSDIR

with ./latest containing the last nightly build run.  Older logs are
archived and available for a whole week for retrospective analysis.

To push sets and images to a remote location use the upload target:

    # make upload-<set>[,...]

To pull sets and images from a remote location use the download target:

    # make download-<set>[,...]

Logs can be downloaded as well for local inspection.  Note that download
like prefetch will purge all locally existing targets.  Use SERVER to
specify the remote end, e.g. SERVER=user@does.not.exist

Additionally, UPLOADDIR can be used to specify a remote location.  At
this point only "logs" upload cleares and creates directories on the fly.

If you want to script interactive prompts you may use the confirm target
to operate yes or no questions before an action:

    # make info confirm dvd

Last but not least, a rebuild of OPNsense core and plugins on package
sets is invoked using:

    # make hotfix[-<step>]

It will flush all previous packages except for ports, rebuild core and
plugins and sign the sets if enabled.  It can also explicity set "core"
or "plugins".
