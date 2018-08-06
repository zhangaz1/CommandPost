--- === plugins.finalcutpro.timeline.multicam ===
---
--- Multicam Tools.

--------------------------------------------------------------------------------
--
-- EXTENSIONS:
--
--------------------------------------------------------------------------------
local require = require

--------------------------------------------------------------------------------
-- Logger:
--------------------------------------------------------------------------------
local log                               = require("hs.logger").new("multicam")

--------------------------------------------------------------------------------
-- CommandPost Extensions:
--------------------------------------------------------------------------------
local fcp                               = require("cp.apple.finalcutpro")
local i18n                              = require("cp.i18n")

local Do                                = require("cp.rx.go.Do")
local Throw                             = require("cp.rx.go.Throw")

--------------------------------------------------------------------------------
--
-- CONSTANTS:
--
--------------------------------------------------------------------------------

-- MAX_ANGLES -> number
-- Constant
-- The maximum number of angles available.
local MAX_ANGLES = 16

-- ANGLE_TYPES -> table
-- Constant
-- Supported Angle Types
local ANGLE_TYPES = {"Video", "Audio", "Both"}

--------------------------------------------------------------------------------
--
-- THE MODULE:
--
--------------------------------------------------------------------------------
local mod = {}

--- plugins.finalcutpro.timeline.multicam.doCutAndSwitchMulticam(whichMode, whichAngle) -> Statement
--- Function
--- Creates a [Statement](cp.rx.go.Statement.md) to Cut & Switch Multicam.
---
--- Parameters:
---  * whichMode - "Audio", "Video" or "Both" as string
---  * whichAngle - Number of Angle
---
--- Returns:
---  * [Statement](cp.rx.go.Statement.md) to execute
function mod.doCutAndSwitchMulticam(whichMode, whichAngle)
    local cut = nil
    if whichMode == "Audio" then
        cut = fcp:doShortcut("MultiAngleEditStyleAudio")
    end

    if whichMode == "Video" then
        cut = fcp:doShortcut("MultiAngleEditStyleVideo")
    end

    if whichMode == "Both" then
        cut = fcp:doShortcut("MultiAngleEditStyleAudioVideo")
    end

    if not cut then
        return Throw("Unsupported mode: %s", whichMode)
    end

    local switch = fcp.doShortcut("CutSwitchAngle" .. string.format("%02d", whichAngle))

    return Do(fcp:doLaunch()):Then(cut):Then(switch)
end

--------------------------------------------------------------------------------
--
-- THE PLUGIN:
--
--------------------------------------------------------------------------------
local plugin = {
    id = "finalcutpro.timeline.multicam",
    group = "finalcutpro",
    dependencies = {
        ["finalcutpro.commands"]    = "fcpxCmds",
    }
}

--------------------------------------------------------------------------------
-- INITIALISE PLUGIN:
--------------------------------------------------------------------------------
function plugin.init(deps)

    --------------------------------------------------------------------------------
    -- Setup Commands:
    --------------------------------------------------------------------------------
    if deps.fcpxCmds then
        for i = 1, MAX_ANGLES do
            for _, whichType in ipairs(ANGLE_TYPES) do
                deps.fcpxCmds:add("cpCutSwitchAngle" .. string.format("%02d", tostring(i)) .. whichType)
                    :titled(i18n("cpCutSwitch" .. whichType .. "Angle_customTitle", {count = i}))
                    :whenActivated(function() mod.doCutAndSwitchMulticam(whichType, i):Now() end)
            end
        end
    end

    return mod
end

return plugin
