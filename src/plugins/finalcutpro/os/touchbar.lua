--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                       T O U C H B A R     P L U G I N                      --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--- === plugins.finalcutpro.os.touchbar ===
---
--- Virtual Touch Bar Plugin.

--------------------------------------------------------------------------------
--
-- EXTENSIONS:
--
--------------------------------------------------------------------------------
local log										= require("hs.logger").new("touchbar")

local eventtap									= require("hs.eventtap")

local touchbar 									= require("hs._asm.touchbar")

local dialog									= require("cp.dialog")
local fcp										= require("cp.apple.finalcutpro")
local config									= require("cp.config")
local prop										= require("cp.prop")

--------------------------------------------------------------------------------
--
-- CONSTANTS:
--
--------------------------------------------------------------------------------
local PRIORITY				= 1000

local LOCATION_DRAGGABLE 	= "Draggable"
local LOCATION_MOUSE		= "Mouse"
local LOCATION_TIMELINE		= "TimelineTopCentre"

local DEFAULT_VALUE 		= LOCATION_DRAGGABLE

--------------------------------------------------------------------------------
--
-- THE MODULE:
--
--------------------------------------------------------------------------------
local mod = {}

mod.lastLocation = config.prop("lastTouchBarLocation")

mod.location = config.prop("displayTouchBarLocation", DEFAULT_VALUE):watch(function() mod.update() end)

--------------------------------------------------------------------------------
-- SET TOUCH BAR LOCATION:
--------------------------------------------------------------------------------
function mod.updateLocation()

	--------------------------------------------------------------------------------
	-- Get Settings:
	--------------------------------------------------------------------------------
	local displayTouchBarLocation = mod.location()

	--------------------------------------------------------------------------------
	-- Put it back to last known position:
	--------------------------------------------------------------------------------
	local lastLocation = mod.lastLocation()
	if lastLocation then
		mod.touchBarWindow:topLeft(lastLocation)
	end

	--------------------------------------------------------------------------------
	-- Show Touch Bar at Top Centre of Timeline:
	--------------------------------------------------------------------------------
	local timeline = fcp:timeline()
	if displayTouchBarLocation == LOCATION_TIMELINE and timeline:isShowing() then
		--------------------------------------------------------------------------------
		-- Position Touch Bar to Top Centre of Final Cut Pro Timeline:
		--------------------------------------------------------------------------------
		local viewFrame = timeline:contents():viewFrame()
		if viewFrame then
			local topLeft = {x = viewFrame.x + viewFrame.w/2 - mod.touchBarWindow:getFrame().w/2, y = viewFrame.y + 20}
			mod.touchBarWindow:topLeft(topLeft)
		end
	elseif displayTouchBarLocation == LOCATION_MOUSE then

		--------------------------------------------------------------------------------
		-- Position Touch Bar to Mouse Pointer Location:
		--------------------------------------------------------------------------------
		mod.touchBarWindow:atMousePosition()

	end

	--------------------------------------------------------------------------------
	-- Save last Touch Bar Location to Settings:
	--------------------------------------------------------------------------------
	mod.lastLocation(mod.touchBarWindow:topLeft())
end

--- plugins.finalcutpro.os.touchbar.supported <cp.prop: boolean; read-only>
--- Field
--- Is `true` if the plugin is supported on this OS.
mod.supported = prop(function() return touchbar.supported() end)

--- plugins.finalcutpro.os.touchbar.enabled <cp.prop: boolean>
--- Field
--- Is `true` if the plugin is enabled.
mod.enabled = config.prop("displayTouchBar", false):watch(function(enabled)
	--------------------------------------------------------------------------------
	-- Check for compatibility:
	--------------------------------------------------------------------------------
	if enabled and not mod.supported() then
		dialog.displayMessage(i18n("touchBarError"))
		mod.enabled(false)
	end
end)

--- plugins.finalcutpro.os.touchbar.isActive <cp.prop: boolean; read-only>
--- Field
--- Is `true` if the plugin is enabled and the TouchBar is supported on this OS.
mod.isActive = mod.enabled:AND(mod.supported):watch(function(active)
	if active then
		mod.show()
	else
		mod.hide()
	end
end)

function mod.update()
	-- Check if it's active.
	mod.isActive:update()
end

--------------------------------------------------------------------------------
-- SHOW TOUCH BAR:
--------------------------------------------------------------------------------
function mod.show()
	--------------------------------------------------------------------------------
	-- Check if we need to show the Touch Bar:
	--------------------------------------------------------------------------------
	if fcp:isFrontmost() and mod.supported() and mod.enabled() then
		mod.updateLocation()
		mod.touchBarWindow:show()
	end
end

--------------------------------------------------------------------------------
-- HIDE TOUCH BAR:
--------------------------------------------------------------------------------
function mod.hide()
	if mod.supported() then mod.touchBarWindow:hide() end
end

--------------------------------------------------------------------------------
-- TOUCH BAR WATCHER:
--------------------------------------------------------------------------------
local function touchbarWatcher(obj, message)
	if message == "didEnter" then
		mod.mouseInsideTouchbar = true
	elseif message == "didExit" then
		mod.mouseInsideTouchbar = false

		--------------------------------------------------------------------------------
		-- Just in case we got here before the eventtap returned the Touch Bar to normal:
		--------------------------------------------------------------------------------
		mod.touchBarWindow:movable(false)
		mod.touchBarWindow:acceptsMouseEvents(true)
		mod.lastLocation(mod.touchBarWindow:topLeft())
	end
end

function mod.init()
	if mod.supported() then
		--------------------------------------------------------------------------------
		-- New Touch Bar:
		--------------------------------------------------------------------------------
		mod.touchBarWindow = touchbar.new()

		--------------------------------------------------------------------------------
		-- Touch Bar Watcher:
		--------------------------------------------------------------------------------
		mod.touchBarWindow:setCallback(touchbarWatcher)

		--------------------------------------------------------------------------------
		-- Get last Touch Bar Location from Settings:
		--------------------------------------------------------------------------------
		local lastTouchBarLocation = mod.lastLocation()
		if lastTouchBarLocation ~= nil then	mod.touchBarWindow:topLeft(lastTouchBarLocation) end

		--------------------------------------------------------------------------------
		-- Draggable Touch Bar:
		--------------------------------------------------------------------------------
		local events = eventtap.event.types
		touchbarKeyboardWatcher = eventtap.new({events.flagsChanged, events.keyDown, events.leftMouseDown}, function(ev)
			if mod.mouseInsideTouchbar and mod.location() == LOCATION_DRAGGABLE then
				if ev:getType() == events.flagsChanged and ev:getRawEventData().CGEventData.flags == 524576 then
					mod.touchBarWindow:backgroundColor{ red = 1 }
									:movable(true)
									:acceptsMouseEvents(false)
				elseif ev:getType() ~= events.leftMouseDown then
					mod.touchBarWindow:backgroundColor{ white = 0 }
								  :movable(false)
								  :acceptsMouseEvents(true)
					mod.lastLocation(mod.touchBarWindow:topLeft())
				end
			end
			return false
		end):start()

		mod.update()
	end
end

--------------------------------------------------------------------------------
--
-- THE PLUGIN:
--
--------------------------------------------------------------------------------
local plugin = {
	id = "finalcutpro.os.touchbar",
	group = "finalcutpro",
	dependencies = {
		["finalcutpro.menu.tools"]		= "prefs",
		["finalcutpro.commands"]	= "fcpxCmds",
	}
}

--------------------------------------------------------------------------------
-- INITIALISE PLUGIN:
--------------------------------------------------------------------------------
function plugin.init(deps)
	mod.init()

	--------------------------------------------------------------------------------
	-- Disable/Enable the Touchbar when the Command Editor/etc is open:
	--------------------------------------------------------------------------------
	fcp:commandEditor():watch({
		show		= function() mod.hide() end,
		hide		= function() mod.show() end,
	})
	fcp:mediaImport():watch({
		show		= function() mod.hide() end,
		hide		= function() mod.show() end,
	})
	fcp:watch({
		active		= function() mod.show() end,
		inactive	= function() mod.hide() end,
		move		= function() mod.update() end,
	})

	--------------------------------------------------------------------------------
	-- Menu items:
	--------------------------------------------------------------------------------
	local section = deps.prefs:addSection(PRIORITY)

	section:addMenu(2000, function() return i18n("touchBar") end)
		:addItems(1000, function()
			local location = mod.location()
			return {
				{ title = i18n("enableTouchBar"), 		fn = function() mod.enabled:toggle() end, 				checked = mod.enabled(),					disabled = not mod.supported() },
				{ title = "-" },
				{ title = string.upper(i18n("touchBarLocation") .. ":"),		disabled = true },
				{ title = i18n("topCentreOfTimeline"), 	fn = function() mod.setLocation(LOCATION_TIMELINE) end,		checked = location == LOCATION_TIMELINE,	disabled = not mod.supported() },
				{ title = i18n("mouseLocation"), 		fn = function() mod.setLocation(LOCATION_MOUSE) end,		checked = location == LOCATION_MOUSE, 		disabled = not mod.supported() },
				{ title = i18n("draggable"), 			fn = function() mod.setLocation(LOCATION_DRAGGABLE) end,	checked = location == LOCATION_DRAGGABLE, 	disabled = not mod.supported() },
				{ title = "-" },
				{ title = i18n("touchBarTipOne"), 		disabled = true },
				{ title = i18n("touchBarTipTwo"), 		disabled = true },
			}
		end)

	--------------------------------------------------------------------------------
	-- Commands:
	--------------------------------------------------------------------------------
	deps.fcpxCmds:add("cpToggleTouchBar")
		:activatedBy():ctrl():option():cmd("z")
		:whenActivated(function() mod.enabled:toggle() end)

	return mod
end

return plugin