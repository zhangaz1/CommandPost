--- === cp.apple.finalcutpro.menu ===
---
--- Final Cut Pro Menu.

local require = require

--local log           = require "hs.logger".new "fcpMenu"

local axutils       = require "cp.ui.axutils"
local destinations  = require "cp.apple.finalcutpro.export.destinations"
local fcpApp        = require "cp.apple.finalcutpro.app"
local strings       = require "cp.apple.finalcutpro.strings"
local tools         = require "cp.tools"

local moses         = require "moses"

local childMatching = axutils.childMatching
local childWith     = axutils.childWith

local isEqual       = moses.isEqual
local trim          = tools.trim

local menu          = fcpApp:menu()

----------------------------------------------------------------------------------------
-- Add a finder for Share Destinations:
----------------------------------------------------------------------------------------
menu:addMenuFinder(function(parentItem, path, childName)
    if isEqual(path, {"File", "Share"}) then
        ----------------------------------------------------------------------------------------
        -- Note, that in German, there's a space between the '…", for example:
        -- 'Super DVD …'
        ----------------------------------------------------------------------------------------
        local childNameClean = childName:match("(.*)…$")
        childName = childNameClean and trim(childNameClean) or childName
        local index = destinations.indexOf(childName)
        if index then
            local children = parentItem:attributeValue("AXChildren")
            return children[index]
        end
    end
end)

----------------------------------------------------------------------------------------
-- Add a finder for missing menus:
----------------------------------------------------------------------------------------
local missingMenuMap = {
    { path = {"Final Cut Pro"},                 child = "Commands",                 key = "CommandSubmenu" },
    { path = {"Final Cut Pro", "Commands"},     child = "Customize…",               key = "Customize" },
    { path = {"Clip"},                          child = "Open Clip",                key = "FFOpenInTimeline" },
    { path = {"Clip"},                          child = "Open in Angle Editor",     key = "FFOpenInAngleEditor" },
    { path = {"Window", "Show in Workspace"},   child = "Sidebar",                  key = "PEEventsLibrary" },
    { path = {"Window", "Show in Workspace"},   child = "Timeline",                 key = "PETimeline" },
    { path = {"Window", "Show in Workspace"},   child = "Event Viewer",             key = "PEEventViewer" },
    { path = {"Window", "Show in Workspace"},   child = "Timeline Index",           key = "PEDataList" },
    { path = {"Window"},                        child = "Extensions",               key = "FFExternalProviderMenuItemTitle" },
    { path = {"File"},                          child = "Close Library.*",          key = "FFCloseLibraryFormat" },
    { path = {"Edit"},                          child = ".*Undo.*",                 key = "FFUndo" },
    { path = {"Edit"},                          child = ".*Redo.*",                 key = "FFRedo" },
    { path = {"Window", "Workspaces"},          child = "Update ‘.*’ Workspace",    key = "PEWorkspacesMenuUpdateWithName" },
    { path = {"Window", "Extensions"} },
    { path = {"Final Cut Pro", "Commands"} },
    { path = {"Window", "Workspaces"} },
}
menu:addMenuFinder(function(parentItem, path, childName, locale)
    for _,item in ipairs(missingMenuMap) do
        if item.child == nil and item.key == nil then
            ----------------------------------------------------------------------------------------
            -- Only the path is supplied (in the missing menu map):
            ----------------------------------------------------------------------------------------
            if isEqual(path, item.path) then
                return childWith(parentItem, "AXTitle", childName)
            end
        elseif string.match(childName, "%.%*") then
            ----------------------------------------------------------------------------------------
            -- Add support for Pattern Matching with Tokens:
            ----------------------------------------------------------------------------------------
            local itemChild = item.child:gsub("%%@", ".*")
            if isEqual(path, item.path) and childName == itemChild then
                local keyWithPattern = strings:find(item.key, locale):gsub("%%@", ".*")
                return childMatching(parentItem, function(child)
                    local title = child:title()
                    return title and string.match(title, keyWithPattern)
                end)

            end
        elseif isEqual(path, item.path) and childName == item.child then
            ----------------------------------------------------------------------------------------
            -- When path, child and key is supplied without patterns or tokens:
            ----------------------------------------------------------------------------------------
            local currentValue = strings:find(item.key, locale)
            return childWith(parentItem, "AXTitle", currentValue)
        end
    end
end)

return menu