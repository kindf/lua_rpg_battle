
local C = require("shared.constants")
local Log = require("shared.log")
local Data = require("data.game_data")
local Combat = require("ch6_activate.combat")
local Targeting = require("ch6_activate.targeting")
local AD = require("ch3_character.action_delegator")
local class = require("shared.class").class

local g_ActionDelegator = AD.g_ActionDelegator

local CondDep = {}
CondDep.__index = CondDep

function CondDep.new()
    return setmetatable({}, CondDep)
end

function CondDep:ConditionCheck(rMr, term)
    local params = rMr:GetTargetingAndDepletingParams()
    if term.kind == "mp" then
        if rMr:GetMP() < term.value then
            params:SetErrCode(C.OR_LACK_MANA)
            Log.warn(string.format("%s 没有足够的法力 %s/%s", rMr:GetName(), rMr:GetMP(), term.value))
            return false
        end
    elseif term.kind == "rage" then
        if rMr:GetRage() < term.value then
            params:SetErrCode(C.OR_NOT_ENOUGH_RAGE)
            Log.warn(string.format("%s 没有足够的怒气 %s/%s", rMr:GetName(), rMr:GetRage(), term.value))
            return false
        end
    end
    return true
end

function CondDep:Deplete(rMe, term)
    local params = rMe:GetTargetingAndDepletingParams()
    if term.kind == "mp" then
        if rMe:GetMP() < term.value then
            params:SetErrCode(C.OR_LACK_MANA)
            Log.warn(string.format("%s 没有足够的法力 %s/%s", rMe:GetName(), rMe:GetMP(), term.value))
            return false
        end
        rMe:GetMP(rMe:GetMP() - term.value)
        Log.msg(string.format("%s 消耗 %s 法力", rMe:GetName(), term.value))
    elseif term.kind == "rage" then
        if rMe:GetRage() < term.value then
            params:SetErrCode(C.OR_NOT_ENOUGH_RAGE)
            Log.warn(string.format("%s 没有足够的怒气 %s/%s", rMe:GetName(), rMe:GetRage(), term.value))
            return false
        end
        rMe:GetRage(rMe:GetRage() - term.value)
        Log.msg(string.format("%s 消耗 %s 怒气", rMe:GetName(), term.value))
    end
    return true
end

local g_ConditionAndDepleteCore = CondDep.new()

local function GetTargetObj(rMe)
    local param = rMe:GetTargetingAndDepletingParams()
    return rMe:GetSpecificObjInSameSceneByID(param:GetTargetObj())
end

---------------------------------------------------------------------
--- skillLogic_T 基类
---------------------------------------------------------------------
local SkillLogic_T = class("SkillLogic_T")

-- 子类覆盖接口
function SkillLogic_T:IsPassive() return false end
function SkillLogic_T:CancelSkillEffect(rMe) return false end
function SkillLogic_T:SpecificOperationOnSkillStart(rMe) return true end
function SkillLogic_T:SpecificConditionCheck(rMe) return true end
function SkillLogic_T:SpecificDeplete(rMe) return true end
function SkillLogic_T:EffectOnUnitOnce(rMe, rTar, bCriticalFlag) return true end
function SkillLogic_T:EffectOnUnitEachTick(rMe, rTar, bCriticalFlag) return true end
function SkillLogic_T:OnInterrupt(rMe) return false end
function SkillLogic_T:OnUseSkillSuccessfully(rImp, rMe, rSkill) end

function SkillLogic_T:OnCancel(rMe)
    local params = rMe:GetTargetingAndDepletingParams()
    params:SetErrCode(C.OR_INVALID_SKILL)
    params:SetErrParam(params:GetActivatedSkill())
    return false
end

function SkillLogic_T:IsConditionSatisfied(rMe)
    if not self:CommonConditionCheck(rMe) then
        return false
    end
    if not self:SpecificConditionCheck(rMe) then
        return false
    end
    return true
end

function SkillLogic_T:DepleteProcess(rMe)
    if not self:CommonDeplete(rMe) then
        return false
    end
    if not self:SpecificDeplete(rMe) then
        return false
    end
    return true
end

function SkillLogic_T:CommonConditionCheck(rMe)
    local si = rMe:GetSkillInfo()
    for idx = 0,  C.CONDITION_AND_DEPLETE_TERM_NUMBER - 1 do
        local term = si.condep_terms[idx + 1]
        if term then
            if not g_ConditionAndDepleteCore:ConditionCheck(rMe, term) then
                return false
            end
        end
    end
    if not self:TargetCheckForActivateOnce(rMe) then
        return false
    end
    return true
end

function SkillLogic_T:CommonDeplete(rMe)
    local si = rMe:GetSkillInfo()
    for idx = 0,  C.CONDITION_AND_DEPLETE_TERM_NUMBER - 1 do
        local term = si.condep_terms[idx + 1]
        if term then
            if not g_ConditionAndDepleteCore:Deplete(rMe, term) then
                return false
            end
        end
    end
    return true
end

function SkillLogic_T:TargetCheckForActivateOnce(rMe)
    local si = rMe:GetSkillInfo()
    local params = rMe:GetTargetingAndDepletingParams()

    if si.select_type ~= C.SELECT_TYPE.CHARACTER then
        if si.select_type == C.SELECT_TYPE.POS then
            if rMe:IsOutOfRangePos(params:GetTargetPosition()) then
                Log.warn("目标距离太远")
                return false
            end
        end
        return true
    end

    local pObj = GetTargetObj(rMe)
    if pObj then
        -- 目标对象类型要求
        local byType = si.target_check_by_obj_type
        if byType == 0 and pObj:GetObjType() ~= C.OBJ_TYPE.HUMAN then
            params:SetErrCode(C.OR_INVALID_TARGET)
            params:SetErrParam(0)
            return false
        elseif byType == 1 and pObj:GetObjType() ~= C.OBJ_TYPE.PET then
            params:SetErrCode(C.OR_INVALID_TARGET)
            params:SetErrParam(0)
            return false
        elseif byType == 2 and pObj:GetObjType() ~= C.OBJ_TYPE.MONSTER then
            params:SetErrCode(C.OR_INVALID_TARGET)
            params:SetErrParam(0)
            return false
        end
        -- 使用者和目标应该时友好关系
        if si.target_logic_by_stand == 0 then
            if rMe:IsFriend(pObj) then
                params:SetErrCode(C.OR_INVALID_TARGET)
                params:SetErrParam(0)
                return false
            end
        -- 使用者和目标应该时敌对关系
        elseif si.target_logic_by_stand == 1 then
            if not rMe:IsEnemy(pObj) then
                params:SetErrCode(C.OR_INVALID_TARGET)
                params:SetErrParam(0)
                return false
            end
        end

        local nState = si.target_must_in_special_state
        if nState == 0 and (not pObj:IsAlive()) then
            params:SetErrCode(C.OR_TARGET_DIE)
            params:SetErrParam(0)
            return false
        elseif nState == 1 and pObj:IsAlive() then
            params:SetErrCode(C.OR_INVALID_TARGET)
            params:SetErrParam(0)
            return false
        end

        if rMe:IsOutOfRange(pObj) then
            params:SetErrCode(C.OR_OUT_RANGE)
            params:SetErrParam(0)
            return false
        end
    end
    return true
end

function SkillLogic_T:TargetCheckForEachTick(rMe)
    local si = rMe:GetSkillInfo()
    local params = rMe:GetTargetingAndDepletingParams()
    if si.select_type ~= C.SELECT_TYPE.CHARACTER then
        return true
    end
    local pObj = GetTargetObj(rMe)
    if pObj then
        local nState = si.target_must_in_special_state
        if nState == 0 and (not pObj:IsAlive()) then
            params:SetErrCode(C.OR_TARGET_DIE)
            params:SetErrParam(0)
            return false
        elseif nState == 1 and pObj:IsAlive() then
            params:SetErrCode(C.OR_INVALID_TARGET)
            params:SetErrParam(0)
            return false
        end
        if rMe:IsOutOfRange(pObj) then
            params:SetErrCode(C.OR_OUT_RANGE)
            params:SetErrParam(0)
            return false
        end
    end
    return true
end

function SkillLogic_T:CalculateActionTime(rMe)
    local si = rMe:GetSkillInfo()
    local params = rMe:GetTargetingAndDepletingParams()
    return si.play_action_time
end

function SkillLogic_T:CooldownProcess(rMe)
    Log.fn("SkillLogic_T:CooldownProcess")
    local si = rMe:GetSkillInfo()
    local nPlayActionTime = si.play_action_time
    local nCooldown = si.cooldown_time
    if nCooldown < nPlayActionTime then
        nCooldown = nPlayActionTime
    end
    if si.auto_shot then
        rMe:SetAutoRepeatCooldown(nCooldown)
        Log.msg(string.format("%s 设置自动重复冷却时间 %s", rMe:GetName(), nCooldown))
    else
        rMe:SetCooldown(si.cooldown_id, nCooldown)
        Log.msg(string.format("%s 设置冷却时间 %s", rMe:GetName(), nCooldown))
    end
    Log.back(nil)
end

-- 瞬发
function SkillLogic_T:StartLaunching(rMe)
    Log.fn("SkillLogic_T:StartLaunching")
    local bRet = self:Action_ActivateOnceHandler(rMe)
    Log.back(bRet)
    return bRet
end

-- 聚气
function SkillLogic_T:StartCharging(rMe)
    Log.fn("SkillLogic_T:StartCharging")
    local si = rMe:GetSkillInfo()
    local params = rMe:GetTargetingAndDepletingParams()
    local nMaxTime = si.charge_time
    local bRet
    if nMaxTime <= 0 then
        bRet = self:Action_ActivateOnceHandler(rMe)
    else
        bRet = g_ActionDelegator:RegisterChargeActionForSkill(rMe, si.skill_id, nMaxTime, function()
            return self:Action_ActivateOnceHandler(rMe)
        end)
    end
    if bRet then
        params:SetErrCode(C.OR_OK)
    end
    Log.back(bRet)
    return bRet
end

-- 引导
function SkillLogic_T:StartChanneling(rMe)
    Log.fn("SkillLogic_T:StartChanneling")
    local si = rMe:GetSkillInfo()
    local params = rMe:GetTargetingAndDepletingParams()
    local nMaxTime = si.channel_time
    if nMaxTime <= 0 then
        Log.error("引导时间必须大于0")
        params:SetErrCode(C.OR_ERROR)
        Log.back(false)
        return false
    end
    local bRet = true
    if not params:GetIgnoreConditionCheckFlag() then
        bRet = self:DepleteProcess(rMe)
    end
    if bRet then
        rMe:OnUseSkillSuccessfully(si)
        local ok = g_ActionDelegator:RegisterChannelActionForSkill(rMe, si.skill_id, nMaxTime, si.charges_or_interval, function()
            self:Action_ActivateEachTickHandler(rMe)
        end)
        if ok then
            self:CooldownProcess(rMe)
            params:SetErrCode(C.OR_OK)
            self:ActivateOnce(rMe)
            Log.back(true)
            return true
        end
    end
    Log.back(false)
    return false
end

-- 放技能流程
function SkillLogic_T:Action_ActivateOnceHandler(rMe)
    Log.fn("SkillLogic_T:Action_ActivateOnceHandler")
    local si = rMe:GetSkillInfo()
    local params = rMe:GetTargetingAndDepletingParams()

    if not self:IsConditionSatisfied(rMe) then
        Log.error("条件不满足 -> OR_LIMIT_USE_SKILL")
        Log.back(false)
        return false
    end

    local bRet = true
    if not params:GetIgnoreConditionCheckFlag() then
        bRet = self:DepleteProcess(rMe)
    end

    if bRet then
        rMe:OnUseSkillSuccessfully(si)

        local nPlayActionTime = self:CalculateActionTime(rMe)
        if not g_ActionDelegator:RegisterInstantActionForSkill(rMe, si.skill_id, nPlayActionTime) then
            Log.back(false)
            return false
        end
        rMe:SetActionTime(nPlayActionTime)

        self:CooldownProcess(rMe)

        local nActivateTimes = si.charges_or_interval
        if nActivateTimes <= 0 then
            nActivateTimes = 1
        end
        Log.msg(string.format("%s 发动 %s 次", rMe:GetName(), nActivateTimes))
        for _ = 1, nActivateTimes do
            params:SetDelayTime(params:GetDelayTime() + si.delay_time)
            self:ActivateOnce(rMe)
        end
    end
    Log.back(false)
    return false
end

function SkillLogic_T:Action_ActivateEachTickHandler(rMe)
    Log.fn("SkillLogic_T:Action_ActivateEachTickHandler")
    local si = rMe:GetSkillInfo()
    local params = rMe:GetTargetingAndDepletingParams()
    if self:TargetCheckForEachTick(rMe) then
        params:SetDelayTime(si.delay_time)
        self:ActivateEachTick(rMe)
        Log.back(true)
        return true
    end
    Log.back(false)
    return false
end

-- 一次技能结算
function SkillLogic_T:ActivateOnce(rMe)
    Log.fn("SkillLogic_T:ActivateOnce")
    local si = rMe:GetSkillInfo()
    local params = rMe:GetTargetingAndDepletingParams()

    local targets = {}
    if not Targeting.CalculateTargetList(rMe, targets) then
        Log.warn("无法计算目标")
        Log.back(false)
        return false
    end

    local hitFlags = {}
    for i, pTarget in ipairs(targets) do
        if self:HitThisTarget(rMe, pTarget) then
            hitFlags[i] = true
        end
        Combat.RegisterBeSkillEvent(pTarget, rMe, si.skill_id, si.delay_time)
    end
    params:SetTargetCount(#targets)
    Log.msg(string.format("广播目标队列：%s 个目标", #targets))

    for i, pTarget in ipairs(targets) do
        if hitFlags[i] then
            local bCriticalHit = self:CriticalHitThisTarget(rMe, pTarget)
            self:EffectOnUnitOnce(rMe, pTarget, bCriticalHit)
        end
    end

    Log.back(true)
    return true
end

function SkillLogic_T:ActivateEachTick(rMe)
    Log.fn("SkillLogic_T:ActivateEachTick")
    local si = rMe:GetSkillInfo()
    local targets = {}
    if not Targeting.CalculateTargetList(rMe, targets) then
        Log.warn("无法计算目标")
        Log.back(false)
        return false
    end
    local hitFlags = {}
    for i, pTarget in ipairs(targets) do
        if self:HitThisTarget(rMe, pTarget) then
            hitFlags[i] = true
        end
    end
    for i, pTarget in ipairs(targets) do
        if hitFlags[i] then
            local bCriticalHit = self:CriticalHitThisTarget(rMe, pTarget)
            self:EffectOnUnitEachTick(rMe, pTarget, bCriticalHit)
        end
    end
    Log.back(true)
    return true
end

function SkillLogic_T:HitThisTarget(rMe, rTar)
    local si = rMe:GetSkillInfo()
    if rMe:IsFriend(rTar) then
        return true
    end
    if not Combat.IsHit(rMe, rTar, si.accuracy) then
        Combat.RegisterSkillMissEvent(rTar, rMe, si.skill_id)
        return false
    end
    Combat.RegisterSkillHitEvent(rTar, rMe, si.skill_id)
    return true
end

function SkillLogic_T:CriticalHitThisTarget(rMe, rTar)
    local si = rMe:GetSkillInfo()
    if rMe:IsFriend(rTar) then
        return false
    end
    if Combat.IsCriticalHit(rMe, rTar, si.critical_rate) then
        rMe:OnCriticalHitTarget(si.skill_id, rTar)
        return true
    end
    return false
end

local ImpactsToTarget_T = class("ImpactsToTarget_T", SkillLogic_T)

function ImpactsToTarget_T:EffectOnUnitOnce(rMe, rTar, bCriticalFlag)
    local si = rMe:GetSkillInfo()
    local params = rMe:GetTargetingAndDepletingParams()
    local impactId = si.impact_id
    Log.fn("ImpactsToTarget_T:EffectOnUnitOnce",
        string.format("target=%s impact=%s crit=%s", rTar:GetName(), impactId, bCriticalFlag))
    if impactId ~= C.INVALID_ID then
        Combat.ImpactCore.SendSpecificImpactToUnit(rMe, rTar, impactId, params:GetDelayTime(), g_ActionDelegator:Now())
    end
    Log.back(true)
    return true
end

function ImpactsToTarget_T:EffectOnUnitEachTick(rMe, rTar, bCriticalFlag)
    local si = rMe:GetSkillInfo()
    local params = rMe:GetTargetingAndDepletingParams()
    local impactId = si.tick_impact_id
    Log.fn("ImpactsToTarget_T:EffectOnUnitEachTick",
        string.format("target=%s impact=%s crit=%s", rTar:GetName(), impactId, bCriticalFlag))
    if impactId ~= C.INVALID_ID then
        Combat.ImpactCore.SendSpecificImpactToUnit(rMe, rTar, impactId, params:GetDelayTime(), g_ActionDelegator:Now())
    end
    Log.back(true)
    return true
end

local LogicList = {}
LogicList.__index = LogicList

function LogicList.new()
    return setmetatable({_byID = {}}, LogicList)
end

function LogicList:Register(logicID, logic)
    assert(self._byID[logicID] == nil)
    self._byID[logicID] = logic
end
function LogicList:GetLogicById(logicID)
    return self._byID[logicID]
end

local g_SkillLogicList = LogicList.new()
g_SkillLogicList:Register(1, ImpactsToTarget_T.new())

return {
    SkillLogic_T = SkillLogic_T,
    ImpactsToTarget_T = ImpactsToTarget_T,
    g_SkillLogicList = g_SkillLogicList,
    g_ConditionAndDepleteCore = g_ConditionAndDepleteCore
}
