--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--               A D V A N C E D   F E A T U R E S   M E N U                  --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--- The AUTOMATION > 'Options' > 'Mobile Notifications' menu section

--------------------------------------------------------------------------------
-- CONSTANTS:
--------------------------------------------------------------------------------
local PRIORITY = 10000

--------------------------------------------------------------------------------
-- THE PLUGIN:
--------------------------------------------------------------------------------
local plugin = {}

	--------------------------------------------------------------------------------
	-- DEPENDENCIES:
	--------------------------------------------------------------------------------
	plugin.dependencies = {
		["cp.plugins.finalcutpro.menu.administrator"] = "administrator"
	}

	--------------------------------------------------------------------------------
	-- INITIALISE PLUGIN:
	--------------------------------------------------------------------------------
	function plugin.init(dependencies)
		return dependencies.administrator:addMenu(PRIORITY, function() return i18n("advancedFeatures") end)
	end

return plugin