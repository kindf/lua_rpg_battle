
local C = require("shared.constants")
local Log = require("shared.log")
local Data = require("data.game_data")
local AD = require("ch3_character.action_delegator")
local Combat = require("ch6_activate.combat")
local SkillCoreMod = require("ch4_skill_core.skill_core")
local class = require("shared.class").class

local g_ActionDDelegator = AD.g_ActionDelegator
local g_SkillCore = SkillCoreMod.g_SkillCore

local ERR_NAME = {}

for k, v in pairs(C) do
    if type(k) == "string" and k:sub(1, 3) == "OR_" and type(v) == "number" then
        ERR_NAME[v] = k
    end
end

local Obj_Character = class("Obj_Character")

function Obj_Character:_init(cfg)
    self.id = cfg.id
    self.name = cfg.name
    self.obj_type = cfg.obj_type or C.OBJ_TYPE.HUMAN
    self.camp_id = cfg.camp_id or 1
    self.level = cfg.level or 1
    self.scene = cfg.scene

    self.alive = true
    self.is_active = true
    self.hp = cfg.hp or 1000
    self.max_hp = cfg.hp or 1000
    self.mp = cfg.mp or 1000
    self.rage = cfg.rage or 0
    self.weapon = cfg.weapon or false
    self.known_skills = cfg.known_skills or {}
    self.attack_range = cfg.attack_range or 8.0

    self.position = cfg.position or {m_fX = 0.0, m_fZ = 0.0}
    self.direction = cfg.direction or 0.0
    self.pet = nil
    self.ai = nil

    self.locked_target = C.INVALID_ID
    self.action_end_time = 0
    self.character_logic = C.CHARACTER_LOGIC.IDLE
    self.logic_stopped = false
    self.logic_count = 0

    self.cooldowns = {}
    self.auto_repeat_ready = 0

    self.skill_info = Data.SkillInfo.new()
    self.params = Data.TargetingAndDepletingParams.new()
end

function Obj_Character:GetID() return self.id end
function Obj_Character:GetName() return self.name end
function Obj_Character:GetObjType() return self.obj_type end
function Obj_Character:GetLevel() return self.level end
function Obj_Character:getScene() return self.scene end
function Obj_Character:getWorldPos() return self.position end
function Obj_Character:IsCharacter() return true end
function Obj_Character:IsAlive() return self.alive end
function Obj_Character:IsDie() return not self.alive end
function Obj_Character:IsActiveObj() return self.is_active end
function Obj_Character:GetCampID() return self.camp_id end
function Obj_Character:GetCampData() return {m_nCampID = self.camp_id} end

function Obj_Character:IsEnemy(tar)
    if tar == nil then
        return false
    end
    return self:GetCampID() ~= tar:GetCampID()
end

function Obj_Character:IsFriend(tar)
    return not self:IsEnemy(tar)
end

function Obj_Character:GetHP() return self.hp end
function Obj_Character:GetMaxHP() return self.max_hp end
function Obj_Character:GetMP() return self.mp end
function Obj_Character:GetRage() return self.rage end
function Obj_Character:GetMyPet() return self.pet end
function Obj_Character:GetMyMaster() return nil end
function Obj_Character:GetAIObj() return self.ai end
function Obj_Character:GetHumanAI() return self.ai end
function Obj_Character:GetPetAI() return self.ai end
function Obj_Character:GetLockedTarget() return self.locked_target end
function Obj_Character:HasWeapon() return self.weapon end

function Obj_Character:SetMP(v) self.mp = v end
function Obj_Character:SetRage(v) self.rage = v end
function Obj_Character:SetLockedTarget(id) self.locked_target = id end

function Obj_Character:GetSpecificObjInSameSceneByID(id)
    if id == nil or id == C.INVALID_ID then
        return nil
    end
    return self.scene:GetObjManager():GetObj(id)
end

---------------------------------------------------------------
--- 技能运行时对象
---------------------------------------------------------------

function Obj_Character:GetSkillInfo()
    return self.skill_info
end

function Obj_Character:GetTargetingAndDepletingParams()
    return self.params
end

-- 装备/属性修正数值
function Obj_Character:RefixSkill(si)
end

function Obj_Character:Skill_HaveSkill(skillID, level)
    return self.known_skills[skillID] == true
end

function Obj_Character:Skill_CanUseThisSkillInThisStatue(skillID)
    return true
end

function Obj_Character:Skill_IsSkillCooldowned(skillID)
    local tmpl = Data.g_SkillTemplateDataMgr:GetInstanceByID(skillID)
    if tmpl == nil then
        return true
    end

    if tmpl:IsAutoShotSkill() then
        return g_ActionDDelegator:Now() > self.auto_repeat_ready
    end
    local instId = tmpl:GetSkillInstance(0)
    local inst = Data.g_SkillInstanceDataMgr:GetInstanceByID(instId)
    if inst == nil then
        return true
    end
    local cid = inst.cooldown_id
    if cid == nil or cid == 0 then
        return true
    end
    return g_ActionDDelegator:Now() >= (self.cooldowns[cid] or 0)
end

function Obj_Character:SetCooldown(cooldownID, ms)
    self.cooldowns[cooldownID] = g_ActionDDelegator:Now() + ms
end

function Obj_Character:SetAutoRepeatCooldown(ms)
    self.auto_repeat_ready = g_ActionDDelegator:Now() + ms
end

-----------------------------------------------------------------
--- 距离
-----------------------------------------------------------------
local function dist2(a, b)
    local dx, dz = a.m_fX - b.m_fX, a.m_fZ - b.m_fZ
    return dx * dx + dz * dz
end

function Obj_Character:IsOutOfRange(tar)
    return dist2(self.position, tar:getWorldPos()) > self.attack_range * self.attack_range
end

function Obj_Character:IsOutOfRangePos(pos)
    return dist2(self.postion, pos) > (12.0 * 12.0)
end

-----------------------------------------------------------------
--- 逻辑状态
-----------------------------------------------------------------
function Obj_Character:GetCharacterLogic() return self.character_logic end
function Obj_Character:SetCharacterLogic(l)
    self.character_logic = l
    self.logic_stopped = false
end

function Obj_Character:IsCharacterLogicStopped() return self.logic_stopped end
function Obj_Character:StopCharacterLogic()
    self.logic_stopped = true
end

function Obj_Character:AddLogicCount()
    self.logic_count = self.logic_count + 1
end

function Obj_Character:GetLogicCount()
    return self.logic_count
end

-----------------------------------------------------------------
--- 动作时间
-----------------------------------------------------------------
function Obj_Character:SetActionTime(t)
    self.action_end_time = g_ActionDDelegator:Now() + t
end

function Obj_Character:GetActionTime()
    return math.max(0, self.action_end_time - g_ActionDDelegator:Now())
end

function Obj_Character:CanUseSkillNow()
    if self:GetActionTime() > 0 then
        return false
    end
    return g_ActionDDelegator:CanDoNextAction(self)
end

-----------------------------------------------------------------
--- 技能执行总入口
-----------------------------------------------------------------
function Obj_Character:Do_UseSkill(idSkill, nLevel, idTarget, pTargetPos, fDir, guidTarget)
    Log.fn("Obj_Character::Do_UseSkill", string.format("%s skill=%s lv=%s", self.name, idSkill, nLevel))

    if not self:IsCharacterLogicStopped() then
        self:StopCharacterLogic(true)
    end
    self:AddLogicCount()

    local pos = {m_fX = 0.0, m_fZ = 0.0}
    if pTargetPos then
        pos.m_fX = pTargetPos.m_fX
        pos.m_fZ = pTargetPos.m_fZ
    end

    if not g_SkillCore:ProcessSkillRequest(self, idSkill, nLevel, idTarget, pos, fDir, guidTarget) then
        local r = self:GetTargetingAndDepletingParams():GetErrCode()
        Log.back(ERR_NAME[r] or r)
        return r
    end

    if self:GetCharacterLogic() ~= C.CHARACTER_LOGIC.USE_SKILL or self:IsCharacterLogicStopped() then
        self:SetCharacterLogic(C.CHARACTER_LOGIC.USE_SKILL)
    end

    if g_ActionDDelegator:CanDoNextAction(self) then
        if self:GetCharacterLogic() == C.CHARACTER_LOGIC.USE_SKILL or (not self:IsCharacterLogicStopped()) then
            self:StopCharacterLogic(false)
        end
    end
    Log.back(C.OR_OK)
    return C.OR_OK
end

-----------------------------------------------------------------
--- 事件/效果
-----------------------------------------------------------------
function Obj_Character:OnUseSkillSuccessfully(si)
    Log.msg("Obj_Character::OnUseSkillSuccessfully")
    Combat.Impact_OnUseSkillSuccessfully(self, si)
end

function Obj_Character:OnCriticalHitTarget(skillID, tar)
    Log.msg(string.format("[会心] %s 对 %s 触发会心 (skill %s)", self.name, tar:GetName(), skillID))
end

function Obj_Character:OnDamage(dmg, attacker)
    self.hp = self.hp - dmg
    Log.msg(string.format("%s 受到 %s 伤害", self.name, dmg))
    if self.hp <= 0 then
        self.hp = 0
        self.alive = false
        Log.msg(string.format("%s 死亡", self.name))
    end
end

function Obj_Character:OnHeal(amount, caster)
    self.hp = math.min(self.hp + amount, self.max_hp)
    Log.msg(string.format("%s 恢复 %s 生命", self.name, amount))
end

function Obj_Character:SendOperateResultMsg(code)
    Log.err(string.format("%s 发送操作结果 %s", self.name, ERR_NAME[code] or code))
end

return {Obj_Character = Obj_Character}
