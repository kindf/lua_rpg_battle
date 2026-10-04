
local Log = require("shared.log")
local AD = require("ch3_character.action_delegator")
local Combat = require("ch6_activate.combat")
local class = require("shared.class").class

local g_ActionDelegator = AD.g_ActionDelegator
local Heartbeat = class("Heartbeat")

function Heartbeat.Tick(scene, uTime)
    g_ActionDelegator:Tick(uTime)

    for _, obj in ipairs(scene:GetObjManager():GetAll()) do
        local ai = obj:GetAIObj()
        if ai then
            ai:Logic(uTime)
        end
    end
    Combat.ImpactCore.Tick(uTime)
end

function Heartbeat.Run(scene, ticks, dtMs)
    local t = 0
    for i = 1, ticks do
        t = t + dtMs
        Log.depth = 0
        print(string.format("\n--- [心跳 %s] uTime=%sms ---", i, t))
        Heartbeat.Tick(scene, t)
    end
    return t
end

return Heartbeat
