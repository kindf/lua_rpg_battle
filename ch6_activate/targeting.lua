
local C = require("shared.constants")
local Log = require("shared.log")

local Targeting = {}

-- hostile=true 只取敌人；hostile=false 只取友军
local function ScanUnitForTarget(rMe, x, z, rTargets, radius, hostile)
    local scene = rMe:getScene()
    local objs = scene:GetObjManager():GetAll()
    for _, obj in ipairs(objs) do
        if obj ~= rMe and obj:IsCharacter() and obj:IsAlive() then
            local pos = obj:getWorldPos()
            local dx, dz = pos.m_fX - x, pos.m_fZ - z
            if (dx * dx + dz * dz) <= radius * radius then
                local ok
                if hostile then ok = rMe:IsEnemy(obj) else ok = rMe:IsFriend(obj) end
                if ok then table.insert(rTargets, obj) end
            end
        end
    end
end

-- rTargets 由调用方传入（已清空），返回 bRet
function Targeting.CalculateTargetList(rMe, rTargets)
    Log.fn("SkillLogic_T::CalculateTargetList")

    local si = rMe:GetSkillInfo()
    local params = rMe:GetTargetingAndDepletingParams()
    local mode = si.targeting_logic
    local bRet = false
    local hostile = (si.stand_flag or 0) < 0

    if mode == C.TARGET_LOGIC.SELF then
        table.insert(rTargets, rMe)
        bRet = true

    elseif mode == C.TARGET_LOGIC.MY_PET then
        local pet = rMe:GetMyPet()
        if pet then table.insert(rTargets, pet); bRet = true end

    elseif mode == C.TARGET_LOGIC.MY_MASTER then
        local master = rMe:GetMyMaster()
        if master then table.insert(rTargets, master); bRet = true end

    elseif mode == C.TARGET_LOGIC.AE_AROUND_SELF then
        local pos = rMe:getWorldPos()
        ScanUnitForTarget(rMe, pos.m_fX, pos.m_fZ, rTargets, si.ae_radius, hostile)
        bRet = true

    elseif mode == C.TARGET_LOGIC.SPECIFIC_UNIT then
        local pTarget = rMe:GetSpecificObjInSameSceneByID(params:GetTargetObj())
        if pTarget then table.insert(rTargets, pTarget); bRet = true end

    elseif mode == C.TARGET_LOGIC.AE_AROUND_UNIT then
        local pTarget = rMe:GetSpecificObjInSameSceneByID(params:GetTargetObj())
        if pTarget then
            local pos = pTarget:getWorldPos()
            ScanUnitForTarget(rMe, pos.m_fX, pos.m_fZ, rTargets, si.ae_radius, hostile)
            bRet = true
        end

    elseif mode == C.TARGET_LOGIC.AE_AROUND_POSITION then
        local pos = params:GetTargetPosition()
        ScanUnitForTarget(rMe, pos.m_fX, pos.m_fZ, rTargets, si.ae_radius, hostile)
        bRet = true

    else
        bRet = false
    end

    Log.msg(string.format("目标模式=%d, 命中目标数=%d", mode, #rTargets))
    Log.back(bRet)
    return bRet
end

return Targeting
