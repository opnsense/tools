--
-- Copyright (C)2009 Scott Ullrich.  All rights reserved.
-- sullrich@gmail.com
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions
-- are met:
--
-- 1. Redistributions of source code must retain the above copyright
--    notices, this list of conditions and the following disclaimer.
-- 2. Redistributions in binary form must reproduce the above copyright
--    notices, this list of conditions, and the following disclaimer in
--    the documentation and/or other materials provided with the
--    distribution.
-- 3. Neither the names of the copyright holders nor the names of their
--    contributors may be used to endorse or promote products derived
--    from this software without specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
-- ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES INCLUDING, BUT NOT
-- LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
-- FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE
-- COPYRIGHT HOLDERS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
-- INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
-- BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
-- LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
-- CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
-- LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
-- ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.
--

-- BEGIN 100_create_zfs_pool.lua --

-- This module requires FreeBSD
if App.conf.os.name ~= "FreeBSD" then
       return nil, "module requires FreeBSD"
end

return {
    id = "createzfspool",
    name = _("Create ZFS Pool"),
    effect = function(step)

	local response = App.ui:present{
	    id = "createazfspool",
	    name = _("Pool Name"),
	    short_desc = _("Pool Name"),
	    fields = {
			{
			    id = "poolname",
			    name = _("Pool name"),
			    short_desc = _("Enter the name of the ZFS pool")
			}			
	    },
	    actions = {
			{
			    id = "ok",
			    name = _("Next step")
			},
			{
			    id = "cancel",
			    accelerator = "ESC",
			    name = _("Return to Previous Menu")
			}
	    },
	    datasets = {
			{
			    poolname = ""
			}
	    }
	})
	
    if response.action_id ~= "ok" then
        return Menu.CONTINUE
    end
	
	local cmds = CmdChain.new()
		cmds:set_replacements{
		    poolname = poolname
		}	
		cmds:add("/sbin/zpool create ${disk}")
	end
	
    -- Finally execute the commands to create the ZFS pool
    if cmds:execute() then
	    -- Survey disks again, they have changed.
	    App.state.storage:survey()
        App.ui:inform(_(
            "The ZFS Pool has been created with no errors.  \n" ..
            "The pool will now appear in the select disk step.\n" ..
			"Alternatively you might want to apply ZFS settings\n" ..
			"and add disks to the newly created pool")
        )
    else
        App.ui:inform(_(
            "The ZFS Pool was NOT created due to errors.")
        )
    end

	return Menu.CONTINUE

end

}
