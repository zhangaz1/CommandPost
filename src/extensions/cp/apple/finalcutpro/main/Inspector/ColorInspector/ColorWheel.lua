--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                   F I N A L    C U T    P R O    A P I                     --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--- === cp.apple.finalcutpro.main.Inspector.ColorInspector.ColorWheel ===
---
--- Represents a single Color Well in the Color Wheels Inspector.
---
--- Requires Final Cut Pro 10.4 or later.
--
-----------------------------------------------------------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--
-- EXTENSIONS:
--
--------------------------------------------------------------------------------
local log                               = require("hs.logger").new("colorWheel")

local prop                              = require("cp.prop")
local axutils							= require("cp.ui.axutils")

local ColorWell							= require("cp.apple.finalcutpro.main.Inspector.ColorInspector.ColorWell")
local ValueIndicator					= require("cp.apple.finalcutpro.main.Inspector.ColorInspector.ValueIndicator")
local Button							= require("cp.ui.Button")

local ColorWheel = {}

--- cp.apple.finalcutpro.main.Inspector.ColorInspector.ColorWheel.TYPE
--- Constant
--- The possible types of ColorWheels: MASTER, SHADOWS, MIDTONES, HIGHLIGHTS.
ColorWheel.TYPE = {
	MASTER = { single = 1, all = 1 },
	SHADOWS = { single = 2, all = 3 },
	MIDTONES = { single = 3, all = 4 },
	HIGHLIGHTS = { single = 4, all = 2 },
}

--- cp.apple.finalcutpro.main.Inspector.ColorInspector.ColorWheel.matches(element)
--- Function
--- Checks if the specified element is a Color Well.
---
--- Parameters:
--- * element	- The element to check
---
--- Returns:
--- * `true` if the element is a Color Well.
function ColorWheel.matches(element)
	if element and element:attributeValue("AXRole") == "AXGroup" and #element == 4 then
		return axutils.childMatching(element, ColorWell.matches) ~= nil
	end
	return false
end

--- cp.apple.finalcutpro.main.Inspector.ColorInspector.ColorWheel:new(parent, type) -> ColorWheel
--- Method
--- Creates a new `ColorWheel` instance, with the specified parent and type.
---
--- Parameters:
--- * parent	- The parent object.
--- * type		- The type of color wheel. Must be one of the `ColorWheel.TYPE` values.
---
--- Returns:
--- * A new `ColorWheel` instance.
function ColorWheel:new(parent, type)
	local o = prop.extend({
		_parent = parent,
		_type = type,
	}, ColorWheel)

--- cp.apple.finalcutpro.main.Inspector.ColorInspetor.ColorWheel.colorValue <cp.prop: hs.drawing.color>
--- Field
--- The current color value, as a `hs.drawing.color` table.
	o.colorValue = o:colorWell().value:wrap(o)

--- cp.apple.finalcutpro.main.Inspector.ColorInspetor.ColorWheel.saturationValue <cp.prop: number>
--- Field
--- The current saturation value, as a number between 0 and 10.
	o.saturationValue = o:saturation().value:wrap(o)

--- cp.apple.finalcutpro.main.Inspector.ColorInspetor.ColorWheel.brightnessValue <cp.prop: number>
--- Field
--- The current brightness value, as a number between -12 and 10.
	o.brightnessValue = o:brightness().value:wrap(o)

	return o
end

function ColorWheel:parent()
	return self._parent
end

function ColorWheel:app()
	return self:parent():app()
end

function ColorWheel:UI()
	return axutils.cache(self, "_ui",
		function()
			local ui = self:parent():contentUI()
			if ui then
				if self:parent():viewingAllWheels() then
					return axutils.childFromTop(ui, 2 + self._type.all)
				elseif self:parent():wheelType():selectedItem() == self._type.single then
					return axutils.childFromTop(ui, 4)
				end
			end
			return nil
		end
	, ColorWheel.matches)
end

function ColorWheel:isShowing()
	return self:UI() ~= nil
end

function ColorWheel:show()
	self:parent():show()
	-- ensure the wheel type is correct, if visible.
	local wheelType = self:parent():wheelType()
	if wheelType:isShowing() then
		wheelType:selectedItem(self._type.single)
	end
	return self
end

--- cp.apple.finalcutpro.main.Inspector.ColorInspector.ColorWheel:colorWell() -> ColorWell
--- Method
--- Returns the `ColorWell` for this ColorWheel.
---
--- Parameters:
--- * None
---
--- Returns:
--- * The `ColorWell` instance.
function ColorWheel:colorWell()
	if not self._colorWell then
		self._colorWell = ColorWell:new(self, function()
			return axutils.childMatching(self:UI(), ColorWell.matches)
		end)
	end
	return self._colorWell
end

--- cp.apple.finalcutpro.main.Inspector.ColorInspector.ColorWheel:saturation() -> ValueIndicator
--- Method
--- Returns the saturation `ValueIndicator` for this ColorWheel.
---
--- Parameters:
--- * None
---
--- Returns:
--- * The saturation `ValueIndicator` instance.
function ColorWheel:saturation()
	if not self._saturation then
		self._saturation = ValueIndicator:new(self,
			function()
				return axutils.childFromLeft(self:UI(), 1)
			end,
			0, 10,
			function(value) -- toAXValue
				return value / 2
			end,
			function(value) -- fromAXValue
				return value * 2
			end
		)
	end
	return self._saturation
end

--- cp.apple.finalcutpro.main.Inspector.ColorInspector.ColorWheel:brightness() -> ValueIndicator
--- Method
--- Returns the brightness `ValueIndicator` for this ColorWheel.
---
--- Parameters:
--- * None
---
--- Returns:
--- * The brightness `ValueIndicator` instance.
function ColorWheel:brightness()
	if not self._brightness then
		self._brightness = ValueIndicator:new(self,
			function()
				return axutils.childFromRight(axutils.childrenWithRole(self:UI(), "AXValueIndicator"), 1)
			end,
			-12, 10,
			function(value) -- toAXValue
				return (value+1)/2
			end,
			function(value) -- fromAXValue
				return value*2-1
			end
		)
	end
	return self._brightness
end

--- cp.apple.finalcutpro.main.Inspector.ColorInspector.ColorWheel:resetButton() -> Button
--- Method
--- Returns the `Button` that triggers a value reset.
---
--- Parameters:
--- * None
---
--- Returns:
--- * The reset `Button` instance.
function ColorWheel:resetButton()
	if not self._resetButton then
		self._resetButton = Button:new(self, function()
			return axutils.childWithRole(self:UI(), "AXButton")
		end)
	end
	return self._resetButton
end

--- cp.apple.finalcutpro.main.Inspector.ColorInspector.ColorWheel:reset() -> ColorWheel
--- Method
--- Resets the color wheel values, if the ColorWheel is showing.
---
--- Parameters:
--- * None
---
--- Returns:
--- * The ColorWheel instance.
function ColorWheel:reset()
	return self:resetButton():press()
end

return ColorWheel