--[[
    Created by Slothpala 
    Build an always up to date cache of all frames in the raid roster
    All hooks that benefit from that cache will be stored here for performance reasons. Modules will register callback functions(frame) for a given hook. The first time that a module registers a callback will start the hook.
--]]
--lua speed reference
local pairs = pairs
local match = match
--wow api speed reference
local IsForbidden = IsForbidden
local UnitIsPlayer = UnitIsPlayer
local UnitIsConnected = UnitIsConnected
local UnitIsDead = UnitIsDead
local UnitIsTapDenied = UnitIsTapDenied
---------
--cache--
---------
local LGF = LibStub("LibGetFrame-1.0")
local Roster = {}
Roster.FramePool = {}
Roster.Units  = {}
local TrackedUnits = {}
Roster.Units["player"] = LGF.GetUnitFrame("player")
TrackedUnits["player"] = true
for i=1,4 do Roster.Units["party"..i] = LGF.GetUnitFrame("party"..i); TrackedUnits["party"..i] = true end
for i=1,40 do Roster.Units["raid"..i] = LGF.GetUnitFrame("raid"..i); TrackedUnits["raid"..i] = true  end
local groupType = ""
local inGroup = false
RaidFrameSettings:RegisterEvent("GROUP_ROSTER_UPDATE",function()
    groupType = IsInRaid() and "raid" or "party"
    inGroup = IsInGroup() 
end)
RaidFrameSettings:RegisterEvent("PLAYER_ENTERING_WORLD",function()
    groupType = IsInRaid() and "raid" or "party"
    inGroup = IsInGroup() 
end)

local OnFrameUnitAdded_Callback = nil
function RaidFrameSettings:RegisterOnFrameUnitAdded(callback)
    OnFrameUnitAdded_Callback = callback
end
local OnFrameUnitUpdate_Callback = nil
function RaidFrameSettings:RegisterOnFrameUnitUpdate(callback)
    OnFrameUnitUpdate_Callback = callback
end
local OnFrameUnitRemoved_Callback = nil
function RaidFrameSettings:RegisterOnFrameUnitRemoved(callback)
    OnFrameUnitRemoved_Callback = callback
end

local callback = function(event, frame, unit, previousUnit)
    if not TrackedUnits[unit] then return end
    if unit == "player" and not frame.healthBar then return end --even with ignored playerFrames GetUnitFrame("player") always returned the _G.PlayerFrame.
    if event == "FRAME_UNIT_ADDED" then
        Roster.FramePool[frame] = true
        Roster.Units[unit] = frame
        if OnFrameUnitAdded_Callback then
            OnFrameUnitAdded_Callback(frame, unit)
        end
    end
    if event == "FRAME_UNIT_UPDATE" then
        Roster.FramePool[frame] = true
        Roster.Units[unit] = frame
        if OnFrameUnitUpdate_Callback then
            OnFrameUnitUpdate_Callback(frame, unit)
        end
    end
    if event == "FRAME_UNIT_REMOVED" then
        Roster.FramePool[frame] = nil
        Roster.Units[unit] = nil
        if OnFrameUnitRemoved_Callback then
            OnFrameUnitRemoved_Callback(unit)
        end
    end
end

LGF.RegisterCallback("RaidFrameSettings", "FRAME_UNIT_ADDED", callback)
LGF.RegisterCallback("RaidFrameSettings", "FRAME_UNIT_UPDATE", callback)
LGF.RegisterCallback("RaidFrameSettings", "FRAME_UNIT_REMOVED", callback)

function RaidFrameSettings:IterateRoster(callback)
    for frame,_ in pairs(Roster.FramePool) do
        callback(frame)
    end
end

---------
--Hooks--
---------
local hooked = {}

local function shouldIgnore(frame) 
    if not frame:IsForbidden() and UnitIsPlayer(frame.unit) and not frame.displayedUnit:match("nameplate") then
        return false
    end
    return true
end

--CompactUnitFrame_UpdateAll 
local OnUpdateAll_Callbacks = {}
function RaidFrameSettings:RegisterOnUpdateAll(callback)
    OnUpdateAll_Callbacks[#OnUpdateAll_Callbacks+1] = callback
    if not hooked["CompactUnitFrame_UpdateAll"] then
        hooksecurefunc("CompactUnitFrame_UpdateAll", function(frame) 
            if Roster.FramePool[frame] or not shouldIgnore(frame) then 
                for i = 1,#OnUpdateAll_Callbacks do 
                    OnUpdateAll_Callbacks[i](frame)
                end
            end
        end)
        hooked["CompactUnitFrame_UpdateAll"] = true
    end
end

--CompactUnitFrame_UpdateHealthColor 
local OnUpdateHealthColor_Callback = function() end
function RaidFrameSettings:RegisterOnUpdateHealthColor(callback)
    OnUpdateHealthColor_Callback = callback
    if not hooked["CompactUnitFrame_UpdateHealthColor"] then
        hooksecurefunc("CompactUnitFrame_UpdateHealthColor", function(frame) 
            if Roster.FramePool[frame] or not shouldIgnore(frame) then
                local unitIsConnected = UnitIsConnected(frame.unit)
                local unitIsDead = unitIsConnected and UnitIsDead(frame.unit)
                if not unitIsConnected or unitIsDead then return end
                OnUpdateHealthColor_Callback(frame)
            end 
        end)
        hooked["CompactUnitFrame_UpdateHealthColor"] = true
    end
end

--CompactUnitFrame_UpdateName 
local OnUpdateName_Callback = function() end
function RaidFrameSettings:RegisterOnUpdateName(callback)
    OnUpdateName_Callback = callback
    if not hooked["CompactUnitFrame_UpdateName"] then
        hooksecurefunc("CompactUnitFrame_UpdateName", function(frame) 
            if Roster.FramePool[frame] or not shouldIgnore(frame) then 
                OnUpdateName_Callback(frame)
            end
        end)
        hooked["CompactUnitFrame_UpdateName"] = true
    end
end

--CompactUnitFrame_UpdateHealPrediction 
local UpdateHealPrediction_Callback = function() end
function RaidFrameSettings:RegisterUpdateHealPrediction(callback)
    UpdateHealPrediction_Callback = callback
    if not hooked["CompactUnitFrame_UpdateHealPrediction"] then
        hooksecurefunc("CompactUnitFrame_UpdateHealPrediction", function(frame) 
            if Roster.FramePool[frame] then
                UpdateHealPrediction_Callback(frame)
            end
        end)
        hooked["CompactUnitFrame_UpdateHealPrediction"] = true
    end
end

--CompactUnitFrame_UpdateInRange 
local UpdateInRange_Callback = function() end
function RaidFrameSettings:RegisterUpdateInRange(callback)
    UpdateInRange_Callback = callback
    if not hooked["CompactUnitFrame_UpdateInRange"] then
        hooksecurefunc("CompactUnitFrame_UpdateInRange", function(frame) 
            if Roster.FramePool[frame] then
                UpdateInRange_Callback(frame)
            end
        end)
        hooked["CompactUnitFrame_UpdateInRange"] = true
    end
end

function RaidFrameSettings:WipeAllCallbacks()
    OnUpdateAll_Callbacks = {}
    OnUpdateHealthColor_Callback = function() end
    OnUpdateName_Callback = function() end
    UpdateInRange_Callback = function() end
    UpdateHealPrediction_Callback = function() end
end
