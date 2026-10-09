local C = require("shared.constants")
local Log = require("shared.log")
local Data = require("data.game_data")

local CGCharUseSkill = {}

CGCharUseSkill.__index = CGCharUseSkill

function CGCharUseSkill.new(t)
    local o = {}
    o.m_ObjID = t.objID
    o.m_SkillDataID = t.skillDataID -- skillID*100 + skillLevel
    o.m_guidTarget = t.m_guidTarget or C.INVALID_GUID
    o.TargetID = t.targetID
    o.m_posTarget = t.posTarget or {m_fX = 0.0, m_fZ = 0.0}
    o.m_fDir = t.fDir or 0.0
    setmetatable(o, CGCharUseSkill)
    return o
end

function CGCharUseSkill:getObjID()
    return self.m_ObjID
end

function CGCharUseSkill:getSkillDataID()
    return self.m_SkillDataID
end

function CGCharUseSkill:getTargetID()
    return self.TargetID
end

function CGCharUseSkill:getTargetGUID()
    return self.m_guidTarget
end

function CGCharUseSkill:getDir()
    return self.m_fDir
end

function CGCharUseSkill:getTargetPos()
    return self.m_posTarget
end

local Handler = {}
Handler.ThreadID = 1

function Handler.Execute(pPacket, pPlayer)
    Log.fn("CGCharUseSkillHandler::Execute")

    if pPlayer == nil then
        Log.error("pGamePlayer == NULL")
        Log.back(C.PACKET_EXE_CONTINUE)
        return C.PACKET_EXE_CONTINUE
    end

    local pHuman = pPlayer:GetHuman()
    if pHuman == nil then
        Log.error("pHuman == NULL")
        Log.back(C.PACKET_EXE_CONTINUE)
        return C.PACKET_EXE_CONTINUE
    end

    local pScene = pHuman:getScene()
    if pScene == nil then
        Log.error("pScene == NULL")
        Log.back(C.PACKET_EXE_CONTINUE)
        return C.PACKET_EXE_CONTINUE
    end

    if pScene.m_ThreadID ~= Handler.ThreadID then
        Log.error("pScene.m_ThreadID != Handler.ThreadID")
        Log.back(C.PACKET_EXE_CONTINUE)
        return C.PACKET_EXE_CONTINUE
    end

    local idSkill = math.floor(pPacket:getSkillDataID() / 100)
    local nLevel = pPacket:getSkillDataID() % 100
    local idTarget = pPacket:getTargetID()
    local guidTarget = pPacket:getTargetGUID()
    local posTarget = pPacket:getTargetPos()
    local fDir = pPacket:getDir()

    Log.msg(string.format("idSkill=%d, nLevel=%d, idTarget=%d, guidTarget=%d, fDir=%f", idSkill, nLevel, idTarget, guidTarget, fDir))

    -- 阵营前置拦截

    local pTarget = pScene:GetObjManager():GetObj(idTarget)
    if pTarget then
        local pSkillTemplate = Data.g_SkillTemplateDataMgr:GetInstanceByID(idSkill)
        local skillType = pSkillTemplate and pSkillTemplate:GetStandFlag() or 0
        if skillType > 0 then
            if pHuman:IsEnemy(pTarget) then
                Log.error(string.format("%s 与 %s 阵营不同 正面技能被拦截", pHuman:GetName(), pTarget:GetName()))
                Log.back(C.PACKET_EXE_CONTINUE)
                return C.PACKET_EXE_CONTINUE
            end
        elseif skillType < 0 then
            if not pHuman:IsEnemy(pTarget) then
                Log.error(string.format("%s 与 %s 阵营不同 背面技能被拦截", pHuman:GetName(), pTarget:GetName()))
                Log.back(C.PACKET_EXE_CONTINUE)
                return C.PACKET_EXE_CONTINUE
            end
        end
    else
        Log.warn("目标不存在 （继续流程）")
    end

    -- 分流技能
    if pPacket:getObjID() == pHuman:GetID() then
        local oResult = pHuman:GetHumanAI():PushCommand_UseSkill(
            idSkill, nLevel, idTarget, posTarget.m_fX, posTarget.m_fX, fDir, guidTarget
        )
        if C.OR_FAILED(oResult) then
            pHuman:SendOperateResultMsg(oResult)
        end
    else
        local pPet = pHuman:GetMyPet()
        if pPet ~= nil and pPet:GetID() == pPacket:getObjID() then
            Log.msg("使用宠物技能")
            pPet:GetPetAI():PushCommand_UseSkill(
                idSkill, nLevel, idTarget, posTarget.m_fX, posTarget.m_fX, fDir, guidTarget
            )
        end
    end

    Log.msg(string.format("S:%s D:%s Skill:%s (%.1f,%.1f) DIR=%.1f", pHuman:GetID(), pPacket:getObjID(), idSkill, posTarget.m_fX, posTarget.m_fZ, fDir))
    Log.back(C.PACKET_EXE_CONTINUE)
    return C.PACKET_EXE_CONTINUE
end

return { CGCharUseSkill = CGCharUseSkill, Handler = Handler }
