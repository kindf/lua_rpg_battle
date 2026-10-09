
local C = require("shared.constants")
local Log = require("shared.log")
local class = require("shared.class").class

---@class State
local State = class("State")

function State:_init(state_id)
    self.state_id = state_id
end

function State:GetStateID()
    return self.state_id
end

function State:CanUseSkill(pAI)
    return C.OR_OK
end

function State:UseSkill(pAI, idSkill, nLevel, idTarget, fTargetX, fTargetZ, fDir, guidTarget)
    Log.fn("State::UseSkill", string.format("skill=%s", idSkill))

    local oResult = self:CanUseSkill(pAI)
    if oResult ~= C.OR_OK then
        Log.back(oResult)
        return oResult
    end

    local pCharacter = pAI:GetCharacter()
    if pCharacter:GetObjType() == C.OBJ_TYPE.HUMAN then
        Log.msg("Human: 不直接执行 -> 交由技能队列")
        Log.back(C.OR_OK)
        return C.OR_OK
    end

    if pCharacter and pCharacter:CanUseSkillNow() then
        local pos = {m_fX = fTargetX, m_fZ = fTargetZ}
        local r = pCharacter:Do_UseSkill(idSkill, nLevel, idTarget, pos, fDir, guidTarget)
        Log.back(r)
        return r
    end
    Log.back(C.OR_OK)
    return oResult
end

function State:Obj_UseSkill(pAI, idSkill, nLevel, idTarget, fTargetX, fTargetZ, fDir, guidTarget)
    Log.fn("State:Obj_UseSkill", string.format("skill=%s", idSkill))

    local pCharacter = pAI:GetCharacter()
    if pCharacter and pCharacter:CanUseSkillNow() then
        local pos = {m_fX = fTargetX, m_fZ = fTargetZ}
        local r = pCharacter:Do_UseSkill(idSkill, nLevel, idTarget, pos, fDir, guidTarget)
        Log.back(r)
        return r
    end
    Log.back(C.OR_OK)
    return C.OR_OK
end

function State:Stop(pAI)
    local pCharacter = pAI:GetCharacter()
    if pCharacter then
        pCharacter:StopCharacterLogic(true)
    end
    return C.OR_OK
end

function State:Logic(pAI, uTime)
    self:StateLogic(pAI, uTime)
    return true
end

function State:StateLogic(pAi, uTime)
end

local IdleState = class("IdleState", State)

function IdleState:StateLogic(pAI, uTime)
    pAI:AI_Logic_Idle(uTime)
end

local CombatState = class("CombatState", State)
function CombatState:StateLogic(pAI, uTime)
    Log.msg("CombatState::StateLogic -> AI_Logic_Combat")
    pAI:AI_Logic_Combat(uTime)
end

local DeadState = class("DeadState", State)
function DeadState:StateLogic(pAI, uTime)
    Log.msg("DeadState::StateLogic -> AI_Logic_Dead")
    pAI:AI_Logic_Dead(uTime)
end

local StateList = class("StateList")
function StateList:_init()
    self._byID = {}
end

function StateList:Register(s)
    self._byID[s:GetStateID()] = s
end

function StateList:InstanceState(id)
    return self._byID[id]
end

local g_StateList = StateList.new()

g_StateList:Register(IdleState.new(C.ESTATE.IDLE))
g_StateList:Register(CombatState.new(C.ESTATE.COMBAT))
g_StateList:Register(DeadState.new(C.ESTATE.DEAD))

return {
    State = State,
    IdleState = IdleState,
    CombatState = CombatState,
    DeadState = DeadState,
    g_StateList = g_StateList
}
