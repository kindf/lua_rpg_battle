-- 运行：  lua main.lua    (或 luajit main.lua)
package.cpath = package.cpath .. ";c:/Users/QQ/.vscode/extensions/tangzx.emmylua-0.9.41-win32-x64/debugger/emmy/windows/x64/?.dll"
local dbg = require("emmy_core")
dbg.tcpConnect("localhost", 9966)

local function script_dir()
    local str = debug.getinfo(1, "S").source:sub(2)
    return str:match("(.*[/\\])") or "./"
end
package.path = script_dir() .. "?.lua;" .. package.path

local C     = require("shared.constants")
local Log   = require("shared.log")
local Data  = require("data.game_data")
local Net   = require("ch1_network.network")
local ObjMod= require("ch3_character.obj_character")
local AIMod = require("ch2_ai.ai_human")
local Heartbeat = require("ch2_ai.heartbeat")
local Combat = require("ch6_activate.combat")
local AD    = require("ch3_character.action_delegator")

--------------------------------------------------------------------------------
-- 场景搭建
--------------------------------------------------------------------------------
local function MakeWorld()
    local scene = Data.Scene.new(1)

    local player = ObjMod.Obj_Character.new({
        id = 1, name = "玩家A", obj_type = C.OBJ_TYPE.HUMAN, camp_id = 1, level = 50,
        hp = 1000, mp = 500, weapon = true, position = { m_fX = 0.0, m_fZ = 0.0 },
        known_skills = { [1001]=true, [1002]=true, [1003]=true, [1004]=true,
                         [1005]=true, [1006]=true, [1007]=true },
        scene = scene,
    })
    local enemy = ObjMod.Obj_Character.new({
        id = 2, name = "山贼", obj_type = C.OBJ_TYPE.MONSTER, camp_id = 2, level = 40,
        hp = 2000, position = { m_fX = 3.0, m_fZ = 0.0 }, scene = scene,
    })
    local enemy2 = ObjMod.Obj_Character.new({
        id = 4, name = "山贼乙", obj_type = C.OBJ_TYPE.MONSTER, camp_id = 2, level = 40,
        hp = 2000, position = { m_fX = 4.0, m_fZ = 1.0 }, scene = scene,
    })
    local friend = ObjMod.Obj_Character.new({
        id = 3, name = "队友B", obj_type = C.OBJ_TYPE.HUMAN, camp_id = 1, level = 45,
        hp = 800, mp = 400, position = { m_fX = -2.0, m_fZ = 0.0 }, scene = scene,
    })

    player.ai = AIMod.AI_Human.new(player)

    scene:GetObjManager():Add(player)
    scene:GetObjManager():Add(enemy)
    scene:GetObjManager():Add(enemy2)
    scene:GetObjManager():Add(friend)

    local pPlayer = { GetHuman = function(self) return player end }
    return { scene = scene, player = player, enemy = enemy, enemy2 = enemy2,
             friend = friend, pPlayer = pPlayer }
end

-- 模拟客户端发包
local function send_skill(pPlayer, human, skillID, level, targetID, pos, dir)
    local pkt = Net.CGCharUseSkill.new({
        objID = human:GetID(),
        skillDataID = skillID * 100 + level,
        targetID = targetID or C.INVALID_ID,
        posTarget = pos or { m_fX = 0.0, m_fZ = 0.0 },
        fDir = dir or 0.0,
    })
    return Net.Handler.Execute(pkt, pPlayer)
end

-- 每个场景开始前清掉上一个场景残留的动作/Impact
local function reset_sim()
    AD.g_ActionDelegator._actions = {}
    AD.g_ActionDelegator._now = 0
    Combat.ImpactCore.CleanUp()
end

--------------------------------------------------------------------------------
-- 场景定义
--------------------------------------------------------------------------------
local scenarios = {}

scenarios[#scenarios + 1] = {
    title = "① 瞬发单体技能 1001 —— 完整链路 + Impact 延迟结算",
    run = function(w)
        send_skill(w.pPlayer, w.player, 1001, 1, w.enemy:GetID())
        Heartbeat.Run(w.scene, 3, 200)
    end,
}

scenarios[#scenarios + 1] = {
    title = "② 包处理层阵营拦截 —— 对队友放攻击技能 1001",
    run = function(w)
        send_skill(w.pPlayer, w.player, 1001, 1, w.friend:GetID())
        -- 队列里应该什么都没有，心跳也不会有动作
        Heartbeat.Run(w.scene, 1, 200)
    end,
}

scenarios[#scenarios + 1] = {
    title = "③ 三连击 1002 —— charges_or_interval = 3，一次心跳连放 3 次",
    run = function(w)
        send_skill(w.pPlayer, w.player, 1002, 1, w.enemy:GetID())
        Heartbeat.Run(w.scene, 4, 200)
    end,
}

scenarios[#scenarios + 1] = {
    title = "④ 范围技 1005 —— TARGET_AE_AROUND_POSITION，命中坐标附近所有敌人",
    run = function(w)
        send_skill(w.pPlayer, w.player, 1005, 1, C.INVALID_ID, { m_fX = 3.0, m_fZ = 0.0 })
        Heartbeat.Run(w.scene, 3, 300)
    end,
}

scenarios[#scenarios + 1] = {
    title = "⑤ 聚气技能 1003 —— 注册充能动作，2 秒后由回调触发",
    run = function(w)
        send_skill(w.pPlayer, w.player, 1003, 1, C.INVALID_ID)
        Heartbeat.Run(w.scene, 5, 500)
    end,
}

scenarios[#scenarios + 1] = {
    title = "⑥ 引导技能 1004 —— 立即生效一次 + 每 1 秒心跳一次",
    run = function(w)
        send_skill(w.pPlayer, w.player, 1004, 1, w.enemy:GetID())
        Heartbeat.Run(w.scene, 7, 500)
    end,
}

scenarios[#scenarios + 1] = {
    title = "⑦ 自动连发技能 1006 —— 走 m_nAutoShotSkill 通道，持续连发",
    run = function(w)
        send_skill(w.pPlayer, w.player, 1006, 1, w.enemy:GetID())
        Heartbeat.Run(w.scene, 5, 300)
    end,
}

scenarios[#scenarios + 1] = {
    title = "⑧ 冷却错误分支 —— 刚放完 1001 又放一次",
    run = function(w)
        send_skill(w.pPlayer, w.player, 1001, 1, w.enemy:GetID())
        Heartbeat.Run(w.scene, 2, 200)          -- t=200 执行, 冷却到 1700
        Log.section("再放一次（此时还在冷却中）")
        send_skill(w.pPlayer, w.player, 1001, 1, w.enemy:GetID())
        Heartbeat.Run(w.scene, 1, 200)          -- t=600 < 1700 -> 冷却报错
    end,
}

--------------------------------------------------------------------------------
-- 主流程
--------------------------------------------------------------------------------
local function main()
    print("lua_combat —— 收包 → ActivateOnce 全链路演示")
    print(string.format("Lua 版本: %s", _VERSION))

    for i, sc in ipairs(scenarios) do
        reset_sim()
        local w = MakeWorld()
        Log.section(string.format("场景 %d/%d  %s", i, #scenarios, sc.title))
        sc.run(w)
        print(string.format("\n[结果] 玩家A HP=%d MP=%d | 山贼 HP=%d | 山贼乙 HP=%d | 队友B HP=%d",
            w.player:GetHP(), w.player:GetMP(), w.enemy:GetHP(), w.enemy2:GetHP(), w.friend:GetHP()))
    end

    print("\n演示结束。")
end

main()
