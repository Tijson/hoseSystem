--
-- Created by IntelliJ IDEA.
-- User: stijn
-- Date: 14-4-2017
-- Time: 00:09
-- To change this template use File | Settings | File Templates.
--

HoseSystemPlayerInteractive = {}
local HoseSystemPlayerInteractive_mt = Class(HoseSystemPlayerInteractive)

function HoseSystemPlayerInteractive:new(object, mt)
    local playerInteractive = {
        object = object
    }

    setmetatable(playerInteractive, mt == nil and HoseSystemPlayerInteractive_mt or mt)

    return playerInteractive
end

function HoseSystemPlayerInteractive:delete()
end

function HoseSystemPlayerInteractive:update(dt)
end

function HoseSystemPlayerInteractive:draw()
end

function HoseSystemPlayerInteractive:getIsPlayerValid(strict)
    if g_currentMission.player.hoseSystem == nil then
        g_currentMission.player.hoseSystem = {}
    end

    strict = strict and g_currentMission.player.hoseSystem.closestIndex == nil or true

    return strict and
            g_currentMission.controlPlayer and
            g_currentMission.player ~= nil and
            g_gui.currentGui == nil and
            not g_currentMission.isPlayerFrozen and
            not g_currentMission.player.hasHPWLance and
            g_currentMission.player.currentTool == nil and
            g_currentMission.player.hoseSystem.index == nil and
            not g_currentMission.player.isCarryingObject
end

---
-- @param superFunc
--
function HoseSystemPlayerInteractive:playerDelete(superFunc)
    if self.hoseSystem ~= nil then
        if self.hoseSystem.interactiveHandling ~= nil and self.hoseSystem.interactiveHandling.drop ~= nil then
            self.hoseSystem.interactiveHandling:drop(self.hoseSystem.index, self)
        end
    end

    if superFunc ~= nil then
        superFunc(self)
    end
end

---
-- @param superFunc
--
function HoseSystemPlayerInteractive:playerOnLeave(superFunc)
    if superFunc ~= nil then
        superFunc(self)
    end

    --    if self.isServer then
    if self.hoseSystem ~= nil then
        if self.hoseSystem.interactiveHandling ~= nil and self.hoseSystem.interactiveHandling.drop ~= nil then
            self.hoseSystem.interactiveHandling:drop(self.hoseSystem.index, self)
        end
    end
    --    end
end

---
-- @param superFunc
-- @param tool
--
function HoseSystemPlayerInteractive:setPlayerTool(superFunc, tool)
    if self.hoseSystem ~= nil and self.hoseSystem.index ~= nil then
        return -- cancel
    end

    if superFunc ~= nil then
        superFunc(self, tool)
    end
end

---
-- @param superFunc
-- @param toolId
-- @param noEventSend
--
function HoseSystemPlayerInteractive:setPlayerToolById(superFunc, toolId, noEventSend)
    if self.hoseSystem ~= nil and self.hoseSystem.index ~= nil then
        return -- cancel
    end

    if superFunc ~= nil then
        superFunc(self, toolId, noEventSend)
    end
end

---
-- @param superFunc
-- @param isTurnedOn
-- @param player
-- @param noEventSend
--
function HoseSystemPlayerInteractive:highPressureWasherSetIsTurnedOn(superFunc, isTurnedOn, player, noEventSend)
    if player ~= nil then
        if player.hoseSystem ~= nil and player.hoseSystem.index ~= nil then
            return -- cancel
        end
    end

    if superFunc ~= nil then
        superFunc(self, isTurnedOn, player, noEventSend)
    end
end

---
-- Override
--
Player.delete = Utils.overwrittenFunction(Player.delete, HoseSystemPlayerInteractive.playerDelete)
Player.onLeave = Utils.overwrittenFunction(Player.onLeave, HoseSystemPlayerInteractive.playerOnLeave)
Player.setTool = Utils.overwrittenFunction(Player.setTool, HoseSystemPlayerInteractive.setPlayerTool)
Player.setToolById = Utils.overwrittenFunction(Player.setToolById, HoseSystemPlayerInteractive.setPlayerToolById)
HighPressureWasher.setIsTurnedOn = Utils.overwrittenFunction(HighPressureWasher.setIsTurnedOn, HoseSystemPlayerInteractive.highPressureWasherSetIsTurnedOn)