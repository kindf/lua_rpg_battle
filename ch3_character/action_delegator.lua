----------------------------------------
---职责：管理当前动作
----------------------------------------

local C = require("shared.constants")
local Log = require("shared.log")
local class = require("shared.class").class

local ActionDelegator = class("ActionDelegator")

function ActionDelegator:__init()
    self._actions = {}
    self._now = 0
end

function ActionDelegator:Now()
    return self._now
end
function ActionDelegator:CanDoNextAction(character)
    local a = self._actions[character:GetID()]
    if a == nil then
        return true
    end
    if self._now >= a.end_time then
        self._actions[character:GetID()] = nil
        return true
    end
    return false
end

function ActionDelegator:RegisterChargeActionForSkill(rMe, skillID, maxTime, on_done)
    Log.fn("ActionDelegator::RegisterChargeActionForSkill", string.format("%s skill=%s", rMe.name, skillID))
    self._actions[rMe:GetID()] = {
        kind = "charge",
        skill_id = skillID,
        end_time = maxTime + self._now,
        on_done = on_done
    }
    Log.back(true)
    return true
end

function ActionDelegator:RegisterChannelActionForSkill(rMe, skillID, maxTime, interval, on_tick)
    Log.fn("ActionDelegator::RegisterChannelActionForSkill", string.format("%s skill=%s", rMe.name, skillID))
    if interval < 500 then
        interval = 2000
    end
    self._actions[rMe:GetID()] = {
        kind = "channel",
        skill_id = skillID,
        end_time = maxTime + self._now,
        interval = interval,
        next_tick = self._now + interval,
        on_tick = on_tick
    }
    Log.back(true)
    return true
end

function ActionDelegator:Tick(uTime)
    self._now = uTime
    for id, a in pairs(self._actions) do
        if a.kind == "charge" and uTime >= a.end_time then
            self._actions[id] = nil
            if a.on_done then
                a.on_done()
            end
        elseif a.kind == "channel" then
            if uTime >= a.end_time then
                self._actions[id] = nil
            elseif a.on_tick and uTime >= a.next_tick then
                a.next_tick = a.next_tick + a.interval
                if a.on_tick() == false then
                    self._actions[id] = nil
                end
            end
        end
    end
end

local g_ActionDelegator = ActionDelegator.new()

return {ActionDelegator = ActionDelegator, g_ActionDelegator = g_ActionDelegator}
