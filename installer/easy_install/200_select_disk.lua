-- $Id: 200_select_disk.lua,v 1.34 2005/08/26 04:25:24 cpressey Exp $

--
-- Select disk onto which to install.
--

return {
    id = "select_disk",
    name = _("Select Disk"),
    req_state = { "storage" },
    effect = function(step)
	App.state.sel_disk = nil
	App.state.sel_part = nil

	-- XXX there might be a better place to handle this.
	if App.state.storage:get_disk_count() == 0 then
		App.ui:inform(_(
		    "The installer could not find any disks suitable "	..
		    "for installation (IDE or SCSI) attached to this "	..
		    "computer.  If you wish to install %s"		..
		    " on an unorthodox storage device, you will have to " ..
		    "exit to a %s command prompt and install it "	..
		    "manually, using the file /README as a guide.",
		    App.conf.product.name, App.conf.media_name)
		)
		return nil
	end

	local dd = {}

	for ddd in App.state.storage:get_disks() do
		local desc = ddd:get_desc()
		if desc == "mirror/pfSenseMirror" then
			print("\nAuto-selecting first disk...")
			print("\npfSense mirror found.  Auto selecting.")
			dd = ddd
			break
		end
	end

	if next(dd) == nil then
		for ddd in App.state.storage:get_disks() do
			dd = ddd
			print("\nAuto-selecting first disk...")
			print(dd:get_desc() .. "\n")
			break
		end
	end

	if dd then
		App.state.sel_disk = dd
		-- App.state.sel_part = App.state.sel_disk:get_part_by_number(1)

		local disk_min_capacity = Storage.Capacity.new(
		    App.conf.limits.part_min
		)
		if disk_min_capacity:exceeds(dd:get_capacity()) then
			App.ui:inform(_(
			    "WARNING: the disk\n\n%s\n\nappears to have a capacity " ..
			    "of %s, which is less than the absolute minimum " ..
			    "recommended capacity, %s. You may encounter "   ..
			    "problems while trying to install %s.",
			    dd:get_name(),
			    dd:get_capacity():format(),
			    disk_min_capacity:format(),
			    App.conf.product.name)
			)
		end

		return step:next()
	else
		return step:prev()
	end
    end
}
