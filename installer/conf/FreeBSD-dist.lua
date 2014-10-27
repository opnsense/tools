--
-- conf/FreeBSD.lua
--
-- This file contains FreeBSD-specific overrides to BSDInstaller.lua.
--

product = {
	name = "FreeBSD",
	version = "8.1"
}

install_items = {
	"boot",
	"COPYRIGHT",
	"bin",
	"dev",
	"etc",
	"libexec",
	"lib",
	"media",
	"root",
	"rescue",
	"sbin",
	"sys",
	"usr",
	"var"
}

cmd_names = cmd_names + {
	DISKLABEL = "sbin/bsdlabel",
	CPDUP = "usr/local/bin/cpdup -vvv -I",
	DHCPD = "usr/local/sbin/dhcpd",
	RPCBIND = "usr/sbin/rpcbind",
	MOUNTD = "usr/sbin/mountd",
	NFSD = "usr/sbin/nfsd",
	MODULES_DIR = "boot/kernel",
	DMESG_BOOT = "var/log/dmesg.boot"
}

sysids = {
	{ "FreeBSD",	165 },
	{ "OpenBSD",	166 },
	{ "NetBSD",		169 },
	{ "MS-DOS",		 15 },
	{ "Linux",		131 },
	{ "Plan9",		 57 }
}

mountpoints = function(part_megs, ram_megs)

	--
	-- First, calculate suggested swap size:
	--
	local swap_megs = 2 * ram_megs
	if ram_megs > (part_megs / 2) or part_megs < 4096 then
		swap_megs = ram_megs
	end
	swap = tostring(swap_megs) .. "M"

        --
        -- The megabytes available on disk for non-swap use.
        --
        local avail_megs = part_megs - swap_megs

	--
	-- Now, based on the capacity of the partition,
	-- return an appropriate list of suggested mountpoints.
	--
	if avail_megs < 300 then
		return {}
	elseif avail_megs < 523 then
		return {
			{ mountpoint = "/",	capstring = "70M" },
			{ mountpoint = "swap",	capstring = swap },
			{ mountpoint = "/var",	capstring = "32M" },
			{ mountpoint = "/tmp",	capstring = "32M" },
			{ mountpoint = "/usr",	capstring = "174M" },
			{ mountpoint = "/home",	capstring = "*" }
		}
	elseif avail_megs < 1024 then
		return {
			{ mountpoint = "/",	capstring = "96M" },
			{ mountpoint = "swap",	capstring = swap },
			{ mountpoint = "/var",	capstring = "64M" },
			{ mountpoint = "/tmp",	capstring = "64M" },
			{ mountpoint = "/usr",	capstring = "256M" },
			{ mountpoint = "/home",	capstring = "*" }
		}
	elseif avail_megs < 4096 then
		return {
			{ mountpoint = "/",	capstring = "128M" },
			{ mountpoint = "swap",	capstring = swap },
			{ mountpoint = "/var",	capstring = "128M" },
			{ mountpoint = "/tmp",	capstring = "128M" },
			{ mountpoint = "/usr",	capstring = "512M" },
			{ mountpoint = "/home",	capstring = "*" }
		}
	elseif avail_megs < 10240 then
		return {
			{ mountpoint = "/",	capstring = "1024M" },
			{ mountpoint = "swap",	capstring = swap },
			{ mountpoint = "/var",	capstring = "512M" },
			{ mountpoint = "/tmp",	capstring = "256M" },
			{ mountpoint = "/usr",	capstring = "3G" },
			{ mountpoint = "/home",	capstring = "*" }
		}
	else
		return {
			{ mountpoint = "/",	capstring = "1024M" },
			{ mountpoint = "swap",	capstring = swap },
			{ mountpoint = "/var",	capstring = "2048M" },
			{ mountpoint = "/tmp",	capstring = "1G" },
			{ mountpoint = "/usr",	capstring = "8G" },
			{ mountpoint = "/home",	capstring = "*" }
		}
	end
end

default_sysid = 165
package_suffix = "tbz"
num_subpartitions = 8
has_raw_devices = false
disklabel_on_disk = false
has_softupdates = true
window_subpartitions = { "c" }
use_cpdup = true

booted_from_install_media = true

dir = { 
	root = "/", 
	tmp = "/tmp/" 
}

--
-- mtrees_post_copy: a table of directory trees to create, using 'mtree',
-- after everything has been copied.
--

mtrees_post_copy = {

}

-- /rescue for example takes a fair amount of space.
limits.part_min = "512M"

--
-- Offlimits mount points and devices.  BSDInstaller will ignore these mount points
--
-- example: offlimits_mounts  = { "unionfs" }
offlimits_mounts  = { "union" }
offlimits_devices = { "fd%d+", "md%d+", "cd%d+" }
