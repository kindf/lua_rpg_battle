
local C = require("shared.constants")
local Log = require("shared.log")
local Data = require("data.game_data")
local AD = require("ch3_character.action_delegator")
local StateMod = require("ch2_ai.state")
local class = require("shared.class").class

local g_ActionDelegator = AD.g_ActionDelegator

local UseSkillParam = class("UseSkillParam")

function UseSkillParam:_init()
    self:CleanUp()
end

function UseSkillParam:CleanUp()
    self.m_nQueueSkill = C.INVALID_SKILL_ID
    self.m_nAutoShotSkill = C.INVALID_SKILL_ID
    self.m_nSkillLevel = 0
    self.m_nQueueTargetObjID = C.INVALID_ID
    self.m_QueueTargetPosition = {m_fX = 0.0, m_fZ = 0.0}
    self.m_fQueueTargetDirection = -1.0
    self.m_guidQueueTarget = C.INVALID_GUID
    self.m_nAutoShotTargetObjID = C.INVALID_ID
end

local UseItemParam = class("UseItemParam")
function UseItemParam:_init()
    self:CleanUp()
end

function UseItemParam:CleanUp()
    self.m_BagInddex = C.INVALID_ID
end

local AI_Character = class("AI_Character")

function AI_Character:_init(pCharacter)
    self.m_pCharacter = pCharacter
    self._state = StateMod.g_StateList:InstanceState(C.ESTATE.IDLE)
end

function  AI_Character:GetCharacter()
    return self.m_pCharacter
end

function AI_Character:GetAIState()
    return self._state
end

function AI_Character:ChangeState(eState)
    if eState == self._state:GetStateID() then
        return
    end
    local s = StateMod.g_StateList:InstanceState(eState)
    if s then
        self._state = s
    end
end

function AI_Character:UseSkill(idSkill, nLevel, idTarget, fTargetX, fTargetZ, fDir, guidTarget)
    return self._state:UseSkill(self, idSkill, nLevel, idTarget, fTargetX, fTargetZ, fDir, guidTarget)
end

function AI_Character:Obj_UseSkill(idSkill, nLevel, idTarget, fTargetX, fTargetZ, fDir, guidTarget)
    return self._state:Obj_UseSkill(self, idSkill, nLevel, idTarget, fTargetX, fTargetZ, fDir, guidTarget)
end

function AI_Character:CanUseSkill()
    return self._state:CanUseSkill(self)
end

function AI_Character:Stop()
    return self._state:Stop(self)
end

function AI_Character:Logic(uTime)
    return self._state:Logic(self, uTime)
end

function AI_Character:IsEnterCombatState()
    return self._state:GetStateID() == C.ESTATE.COMBAT
end
--------------------------------------------------------------
--- AI_Hunam
--- --------------------------------------------------------------
local AI_Human = class("AI_Human", AI_Character)
function AI_Human:_init(pCharacter)
    self.__base._init(self, pCharacter)
    self.m_paramAI_UseSkill = UseSkillParam.new()
    self.m_paramAI_UseItem = UseItemParam.new()
end

function AI_Human:PushCommand_UseSkill(idSkill, nLevel, idTarget, fTargetX, fTargetZ, fDir, guidTarget)
    Log.fn("AI_Hunam::PushCommand_UseSkill", string.format("skill=%s", idSkill))

    if not self:GetCharacter():IsActiveObj() then
        Log.back(C.OR_ERROR)
        return C.OR_ERROR
    end

    local oResult = self:UseSkill(idSkill, nLevel, idTarget, fTargetX, fTargetZ, fDir, guidTarget)

    if oResult == C.OR_OK then
        self:ChangeState(C.ESTATE.COMBAT)

        if not self:IsEnterCombatState(idSkill, nLevel, idTarget) then
            self:PushSkillToQueue(idSkill, nLevel, idTarget, fTargetX, fTargetZ, fDir, guidTarget)
        end
    end
    Log.back(oResult)
    return oResult
end

function AI_Human:PushSkillToQueue(idSkill, nLevel, idTarget, fTargetX, fTargetZ, fDir, guidTarget)
    Log.fn("AI_Hunam::PushSkillToQueue", string.format("skill=%s", idSkill))
    local pSkill = Data.g_SkillTemplateDataMgr:GetInnstanceByID(idSkill)
    if pSkill == nil then
        Log.back(nil)
        return
    end

    local pCharacter = self:GetCharacter()
    if pCharacter then
        local rParams = pCharacter:GetTragetingAndDepletingParams()
        if not g_ActionDelegator:CanDoNextAction(pCharacter) then
            if idSkill == rParams:GetActivatedSkill() then
                Log.msg("过滤掉重复按键")
                Log.back(nil)
                return
            end
        end

        if pSkill:CanInterruptAutoShot() then
            self.m_paramAI_UseSkill.m_nAutoShotSkill = C.INVALID_SKILL_ID
            self.m_paramAI_UseSkill.m_nAutoShotTargetObjID = C.INVALID_ID
        end

        self.m_paramAI_UseSkill.m_nQueueSkill = idSkill
        self.m_paramAI_UseSkill.m_nSkillLevel = nLevel
        self.m_paramAI_UseSkill.m_nQueueTargetObjID = idTarget
        self.m_paramAI_UseSkill.m_QueueTargetPosition.m_fX = fTargetX
        self.m_paramAI_UseSkill.m_QueueTargetPosition.m_fZ = fTargetZ
        self.m_paramAI_UseSkill.m_fQueueTargetDirection = fDir
        self.m_paramAI_UseSkill.m_guidQueueTarget = guidTarget
        Log.msg("已写入 m_nQueueSkill")
    end

    Log.back(nil)
end

function AI_Human:CheckTargetValid(nSkillID, TargetID)
    local tmpl = Data.g_SkillTemplateDataMgr:GetInnstanceByID(nSkillID)
    if tmpl == nil then
        return false
    end

    if tmpl:GetSelectType() == C.SELECT_TYPE.CHARACTER then
        local pObj = self:GetCharacter():GetSpecificObjInSameSceneById(TargetID)
        if pObj == nil then
            return false
        end
        if not pObj:IsCharacter() then
            return false
        end

        local nState = tmpl:GetTargetMustInSpecialState()
        local bMustAlive = (nState == 0 or nState == -1)
        local bMustDead = (nState == 1 or nState == -1)
        local bAlive = pObj:IsAlive()
        if bAlive and bMustAlive then
            return true
        end

        if not bAlive and bMustDead then
            return true
        end

        return false
    end
end

-- 战斗心跳
function AI_Human:AI_Logic_Combat(uTime)
    Log.fn("AI_Human::AI_Logic_Combat", string.format("uTime=%d", uTime))
    local rMe = self:GetCharacter()
    local position = {m_fX = 0.0, m_fZ = 0.0}

    if rMe:CanUseSkillNow() then
        local nAutoActivedSkill = self.m_paramAI_UseSkill.m_nAutoShotSkill
        local nQueuedSkill = self.m_paramAI_UseSkill.m_nQueueSkill
        local BagIndex = self.m_paramAI_UseItem.m_BagIndex

        if BagIndex ~= C.INVALID_ID then
            Log.msg("使用道具")
            self.m_paramAI_UseItem:CleanUp()
        elseif nQueuedSkill ~= C.INVALID_SKILL_ID then
            Log.msg("使用队列技能")
            if not self:CheckTargetValid(nQueuedSkill, self.m_paramAI_UseSkill.m_nQueueTargetObjID) then
                self.m_paramAI_UseSkill:CleanUp()
                self:ChangeState(C.ESTATE.IDLE)
                rMe:SetLockedTarget(C.INVALID_ID)
                Log.msg("目标已失效 回空闲")
                Log.back(nil)
                return
            end

            if not rMe:Skill_IsSkillCoolDowned(nQueuedSkill) then
                rMe:SendOperateResultMsg(C.OR_COOL_DOWNING)
                self.m_paramAI_UseSkill.m_nQueueSkill = C.INVALID_SKILL_ID
                Log.back(nil)
                return
            end
            if not rMe:Skill_CanUseThisSkillInThisStatus(nQueuedSkill) then
                rMe:SendOperateResultMsg(C.OR_U_CANNT_DO_THIS_RIGHT_NOW)
                self.m_paramAI_UseSkill.m_nQueueSkill = C.INVALID_SKILL_ID
                Log.back(nil)
                return
            end

            self:Obj_UseSkill(
                nQueuedSkill,
                self.m_paramAI_UseSkill.m_nSkillLevel,
                self.m_paramAI_UseSkill.m_nQueueTargetObjID,
                self.m_paramAI_UseSkill.m_QueueTargetPosition.m_fX,
                self.m_paramAI_UseSkill.m_QueueTargetPosition.m_fZ,
                self.m_paramAI_UseSkill.m_fQueueTargetDirection,
                self.m_paramAI_UseSkill.m_guidQueueTarget
            )

            self.m_paramAI_UseSkill.m_nQueueSkill = C.INVALID_SKILL_ID
            rMe:SetLockedTarget(self.m_paramAI_UseSkill.m_nQueueTargetObjID)
        elseif nAutoActivedSkill ~= C.INVALID_SKILL_ID then
            Log.msg("使用自动释放技能", string.format("nAutoActivedSkill=%d", nAutoActivedSkill))
            if not self:CheckTargetValid(nAutoActivedSkill, self.m_paramAI_UseSkill.m_nAutoShotTargetObjID) then
                self.m_paramAI_UseSkill:CleanUp()
                self:ChangeState(C.ESTATE.IDLE)
                rMe:SetLockedTarget(C.INVALID_ID)
                Log.msg("目标已失效")
                Log.back(nil)
                return
            end
            if not rMe:Skill_IsSkillCoolDowned(nAutoActivedSkill) then
                Log.back(nil)
                return
            end

            if not rMe:Skill_CanUseThisSkillInThisStatus(nAutoActivedSkill) then
                Log.back(nil)
                return
            end

            local nRet = self:Obj_UseSkill(
                self.m_paramAI_UseSkill.m_nAutoShotSkill,
                self.m_paramAI_UseSkill.m_nSkillLevel,
                self.m_paramAI_UseSkill.m_nAutoShotTargetObjID,
                position.m_fX,
                position.m_fZ,
                0.0,
                C.INVALID_ID
            )

            local pTarget = rMe:GetScene():GetObjManager():GetObj(self.m_paramAI_UseSkill.m_nAutoShotTargetObjID)
            if pTarget and nRet == C.OR_OK and rMe:IsEnemy(pTarget) then
            else
                self.m_paramAI_UseSkill.m_nAutoShotSkill = C.INVALID_SKILL_ID
                self.m_paramAI_UseSkill.m_nAutoShotTargetObjID = C.INVALID_ID
            end
        else
            self:ChangeState(C.ESTATE.IDLE)
            Log.msg("无待放技能 -> 空闲")
            Log.back(nil)
            return
        end
    end
    Log.back(nil)
end


function AI_Human:AI_Logic_Idle(uTime)
    Log.fn("AI_Human:AI_Logic_IDLE")
    Log.back(nil)
end

function AI_Human:AI_Logic_Dead(uTime)
    Log.fn("AI_Human:AI_Logic_Dead")
    Log.back(nil)
end

function AI_Human:ForceInterruptSkill()
    self.m_paramAI_UseSkill:CleanUp()
    g_ActionDelegator:InterruptCurrentAction(self:GetCharacter())
    if self:GetAIState():GetStateID() ~= C.ESTATE.IDLE then
        self:ChangeState(C.STATE.IDLE)
    end
end

return {AI_Character = AI_Character, AI_Human = AI_Human}
