--- === cp.ui.Toolbar ===
---
--- Toolbar Module.

local require = require
local axutils						= require("cp.ui.axutils")
local Element                       = require("cp.ui.Element")
local prop							= require("cp.prop")

local Button                        = require("cp.ui.Button")

local Do                            = require("cp.rx.go").Do

local Toolbar = Element:subtype()

--- cp.ui.Toolbar.matches(element) -> boolean
--- Function
--- Checks if the `element` is a `Button`, returning `true` if so.
---
--- Parameters:
---  * element		- The `hs._asm.axuielement` to check.
---
--- Returns:
---  * `true` if the `element` is a `Button`, or `false` if not.
function Toolbar.matches(element)
    return Element.matches(element) and element:attributeValue("AXRole") == "AXToolbar"
end

--- cp.ui.Toolbar.new(parent, uiFinder) -> cp.ui.Toolbar
--- Constructor
--- Creates a new `Toolbar` instance, given the specified `parent` and `uiFinder`
---
--- Parameters:
---  * parent   - The parent object.
---  * uiFinder   - The `cp.prop` or `function` that finds the `hs._asm.axuielement` that represents the `Toolbar`.
---
--- Returns:
---  * The new `Toolbar` instance.
function Toolbar.new(parent, uiFinder)
    local o = Element.new(parent, uiFinder, Toolbar)

    prop.bind(o) {
--- cp.ui.Toolbar.selectedTitle <cp.prop: string; read-only>
--- Field
--- The title of the first selected item, if available.
        selectedTitle   = o.UI:mutate(function(original)
            local ui = original()
            local selected = ui and ui:attributeValue("AXSelectedChildren")
            if selected and #selected > 0 then
                return selected[1]:attributeValue("AXTitle")
            end
        end),
    }

--- cp.ui.Toolbar.overflowButton <cp.ui.Button>
--- Field
--- The "overflow" button which appears if there are more toolbar items
--- available than can be fit on screen.
    o.overflowButton = Button.new(o, o.UI:mutate(function(original)
        local ui = original()
        return ui and ui:attributeValue("AXOverflowButton")
    end))

    if prop.is(parent.UI) then
        o.UI:monitor(parent.UI)
    end

    if prop.is(parent.isShowing) then
        o.isShowing:monitor(parent.isShowing)
    end

    return o
end

--- cp.ui.Toolbar:doSelect(title) -> Statement
--- Method
--- Returns a `Statement` that will select the toolbar item with the specified title.
---
--- Parameters:
--- * title - The title to select, if present.
---
--- Returns:
--- * A `Statement` that when executed returns `true` if the item was found and selected, otherwise `false`.
function Toolbar:doSelect(title)
    return Do(self:doShow())
    :Then(function()
        local ui = self:UI()
        local selectedTitle = self:selectedTitle()
        if selectedTitle ~= title then
            local button = ui and axutils.childWith(ui, "AXTitle", title)
            if button then
                button:doPress()
                return true
            end
        end
        return false
    end)
end

function Toolbar:doShow()
    return self:parent():doShow()
end

function Toolbar:doHide()
    return self:parent():doHide()
end

return Toolbar
