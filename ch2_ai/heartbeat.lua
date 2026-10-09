
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
    -- 从 ActionDelegator 当前时间续跑，保证多次 Run 调用之间时间单调递增
    -- （reset_sim 会把 _now 归零，因此每个场景仍从 0 重新开始）
    local t = g_ActionDelegator:Now()
    for i = 1, ticks do
        t = t + dtMs
        Log.depth = 0
        print(string.format("\n--- [心跳 %s] uTime=%sms ---", i, t))
        Heartbeat.Tick(scene, t)
    end
    return t
end

return Heartbeat
