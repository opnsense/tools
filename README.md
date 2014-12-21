Setting up a fresh build system
===============================

Install FreeBSD 10.0 amd64 release on a machine with at least
10GB of hard disk + 2GB of RAM, UFS works better than ZFS).
All tasks require a root user.  Do the following to grab
the repositories:

    # pkg install git
    # cd /usr
    # git clone <username>@git.opnsense.org:repo/ports
    # git clone <username>@git.opnsense.org:repo/tools
    # git clone <username>@git.opnsense.org:repo/core
    # git clone <username>@git.opnsense.org:repo/src

Running the build
=================

The build is broken down into individual stages: base,
kernel and ports can be built separately and repeatedly
without affecting the others.  All stages can be reinvoked
and continue building without cleaning the previous progress.
A final stage assembles all three stages into a target image.

Go to the build directory:

    # cd /usr/tools/build

Build the userland binaries, bootloader and administrative
files:

    # ./base.sh

Build the kernel and loadable kernel modules:

    # ./kernel.sh

Build all the ports and wrap them into a single set:

    # ./ports.sh

A bootable LiveCD image is created using:

    # ./iso.sh

Or you can create memstick images for VGA and serial:

    # ./memstick.sh

Some more random information
============================

The OPNsense core package can be rebuilt on its own via:

    # cd /usr/tools/build && ./core.sh

For very fast ports rebuilding of already installed packages
the following works:

    # rm /tmp/packages/<packagename>-*.txz
    # cd /usr/tools/build && ./ports.sh

All individual ports packages are stored under /tmp/packages

Kernel, base and ports sets are stored under /tmp/sets

All final images are stored under /tmp/images
