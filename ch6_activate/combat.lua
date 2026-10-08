local C = require("shared.constants")
local Log = require("shared.log")

local Combat = {}

--------------------------------------------------------------------------------
-- 可复现随机（Lehmer LCG，固定种子 -> 每次运行结果一致，方便对照）
--------------------------------------------------------------------------------
local seed = 20261002
local function rand01()
    seed = (16807 * seed) % 2147483647
    return seed / 2147483647
end
Combat.rand01 = rand01

--------------------------------------------------------------------------------
-- 命中 / 会心（简化公式）
--------------------------------------------------------------------------------
-- 对应 SkillLogic_T::HitThisTarget 里的 IsHit(rMe, rTar, accuracy) 分支
function Combat.IsHit(rMe, rTar, accuracy)
    if rMe:IsFriend(rTar) then
        return true  -- 给友方使用的技能 100% 命中
    end
    return (rand01() * 100) <= accuracy
end

-- 对应 SkillLogic_T::CriticalHitThisTarget 里的 IsCriticalHit
function Combat.IsCriticalHit(rMe, rTar, criticalRate)
    if rMe:IsFriend(rTar) then
        return false -- 友好技能没有会心
    end
    return (rand01() * 100) <= criticalRate
end

--------------------------------------------------------------------------------
-- Impact 表（对应 C++ 的 Impact 数据表，字段做了裁剪）
--------------------------------------------------------------------------------
Combat.IMPACTS = {
    [5001] = { name = "烈焰弹命中", kind = "damage", amount = 120 },
    [5002] = { name = "火雨",       kind = "damage", amount = 80  },
    [5003] = { name = "引导箭",     kind = "damage", amount = 60  },
    [5004] = { name = "治疗术",     kind = "heal",   amount = 200 },
}

--------------------------------------------------------------------------------
-- ImpactCore：延迟生效的效果（对应 Impact 的心跳）
--------------------------------------------------------------------------------
local ImpactCore = {}
Combat.ImpactCore = ImpactCore
ImpactCore.pending = {}
local _seq = 0

-- 对应 Obj_Character::Impact_SendSpecificImpactToUnit / LuaFnSendSpecificImpactToUnit
function ImpactCore.SendSpecificImpactToUnit(caster, target, impact_id, delay_time, uTime)
    local def = Combat.IMPACTS[impact_id]
    _seq = _seq + 1
    table.insert(ImpactCore.pending, {
        seq = _seq, caster = caster, target = target,
        impact_id = impact_id, def = def,
        due = (uTime or 0) + (delay_time or 0), applied = false,
    })
    Log.msg(string.format("注册 Impact %d(%s) -> %s  delay=%dms",
        impact_id, def and def.name or "?", target:GetName(), delay_time or 0))
end

-- 心跳：到期的 Impact 才真正起作用
function ImpactCore.Tick(uTime)
    for _, imp in ipairs(ImpactCore.pending) do
        if (not imp.applied) and uTime >= imp.due then
            imp.applied = true
            local def = imp.def
            if def then
                if def.kind == "damage" then
                    imp.target:OnDamage(def.amount, imp.caster)
                elseif def.kind == "heal" then
                    imp.target:OnHeal(def.amount, imp.caster)
                end
            end
        end
    end
end
function ImpactCore.CleanUp() ImpactCore.pending = {} end

-- 对应 Obj_Character::Impact_OnUseSkillSuccessfully
function Combat.Impact_OnUseSkillSuccessfully(rMe, skill_info)
    Log.msg("Impact_OnUseSkillSuccessfully: 遍历自身 impact，触发各自的 OnUseSkillSuccessfully")
end

--------------------------------------------------------------------------------
-- 事件（对应 EventCore）
--------------------------------------------------------------------------------
function Combat.RegisterSkillHitEvent(rTar, rMe, skillID)
    Log.msg(string.format("事件 SkillHit   : %s <- %s (skill %d)", rTar:GetName(), rMe:GetName(), skillID))
end
function Combat.RegisterSkillMissEvent(rTar, rMe, skillID)
    Log.msg(string.format("事件 SkillMiss  : %s <- %s (skill %d)", rTar:GetName(), rMe:GetName(), skillID))
end
function Combat.RegisterBeSkillEvent(rTar, rMe, skillID, delay)
    Log.msg(string.format("事件 BeSkill   : %s <- %s (skill %d, delay %d)",
        rTar:GetName(), rMe:GetName(), skillID, delay or 0))
end

return Combat

