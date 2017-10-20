--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--      M O B I L E   N O T I F I C A T I O N S   M E N U   S E C T I O N     --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--- === plugins.core.menu.helpandsupport.commandpost ===
---
--- The Help & Support > CommandPost menu section.

--------------------------------------------------------------------------------
--
-- CONSTANTS:
--
--------------------------------------------------------------------------------
local PRIORITY = 10

--------------------------------------------------------------------------------
--
-- THE PLUGIN:
--
--------------------------------------------------------------------------------
local plugin = {
	id				= "core.menu.helpandsupport.commandpost",
	group			= "core",
	dependencies	= {
		["core.menu.helpandsupport"] = "helpandsupport"
	}
}

--------------------------------------------------------------------------------
-- INITIALISE PLUGIN:
--------------------------------------------------------------------------------
function plugin.init(dependencies)
	return dependencies.helpandsupport:addMenu(PRIORITY, function() return i18n("appName") end)
end

return plugin