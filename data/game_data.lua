
local C = require("shared.constants")
local class = require("shared.class").class

local Data = {}

local INVALID_ID = C.INVALID_ID

--------------------------------------------------------------------------------
-- TargetingAndDepletingParams_T
--   C++ 里所有技能函数都只收 Obj_Character&，目标信息是通过这个"上下文对象"传的
--------------------------------------------------------------------------------
local Params = class("TargetingAndDepletingParams_T")
function Params:_init()
    self:CleanUp()
end
function Params:CleanUp()
    self.err_code          = C.OR_OK
    self.err_param         = 0
    self.activated_skill   = C.INVALID_SKILL_ID
    self.skill_level       = 0
    self.target_obj        = INVALID_ID
    self.target_position   = { m_fX = 0.0, m_fZ = 0.0 }
    self.target_direction  = -1.0
    self.target_guid       = C.INVALID_GUID
    self.delay_time        = 0            -- 连击/引导会累加
    self.target_count      = 0
    self.ignore_condition_check_flag = false
    self.activated_script  = C.INVALID_ID
    self.bag_index         = INVALID_ID
    self.item_index        = INVALID_ID
    self.depleted_item_guid= C.INVALID_GUID
end
function Params:SetErrCode(v) self.err_code = v end
function Params:GetErrCode() return self.err_code end
function Params:SetErrParam(v) self.err_param = v end
function Params:SetActivatedSkill(v) self.activated_skill = v end
function Params:GetActivatedSkill() return self.activated_skill end
function Params:SetActivatedScript(v) self.activated_script = v end
function Params:GetActivatedScript() return self.activated_script end
function Params:SetSkillLevel(v) self.skill_level = v end
function Params:GetSkillLevel() return self.skill_level end
function Params:SetTargetObj(v) self.target_obj = v end
function Params:GetTargetObj() return self.target_obj end
function Params:SetTargetPosition(v) self.target_position = v end
function Params:GetTargetPosition() return self.target_position end
function Params:SetTargetDirection(v) self.target_direction = v end
function Params:SetTargetGuid(v) self.target_guid = v end
function Params:SetDelayTime(v) self.delay_time = v end
function Params:GetDelayTime() return self.delay_time end
function Params:SetTargetCount(v) self.target_count = v end
function Params:SetIgnoreConditionCheckFlag(v) self.ignore_condition_check_flag = v end
function Params:GetIgnoreConditionCheckFlag() return self.ignore_condition_check_flag end
function Params:SetBagIndexOfDepletedItem(v) self.bag_index = v end
function Params:GetBagIndexOfDepletedItem() return self.bag_index end
Data.TargetingAndDepletingParams = Params

--------------------------------------------------------------------------------
-- SkillInfo_T：运行时技能实例（InstanceSkill 会把一条 SkillInstanceData_T 拷进来）
--   注意：为便于学习，这里用"直接字段"代替 C++ 的 GetXxx()。
--         si.delay_time       <=> rSkillInfo.GetDelayTime()
--         si.charges_or_interval <=> rSkillInfo.GetChargesOrInterval()
--------------------------------------------------------------------------------
local SkillInfo = class("SkillInfo_T")
function SkillInfo:_init()
    self:Init()
end
function SkillInfo:Init()
    self.skill_id                    = C.INVALID_SKILL_ID
    self.logic_id                    = C.INVALID_ID
    self.skill_type                  = C.SKILL_TYPE.INVALID
    self.delay_time                  = 0
    self.cooldown_id                 = 0
    self.cooldown_time               = 0
    self.play_action_time            = 0
    self.charge_time                 = 0
    self.channel_time                = 0
    self.targeting_logic             = C.TARGET_LOGIC.INVALID
    self.select_type                 = C.SELECT_TYPE.INVALID
    self.target_check_by_obj_type    = -1
    self.target_must_in_special_state= -1
    self.accuracy                    = 0
    self.critical_rate               = 0
    self.must_use_weapon_flag        = false
    self.charges_or_interval         = 0
    self.ae_radius                   = 0.0
    self.impact_id                   = C.INVALID_ID
    self.tick_impact_id              = C.INVALID_ID  -- 引导每跳用的 Impact
    self.auto_shot                   = false
    self.stand_flag                  = 0
    self.target_logic_by_stand       = C.INVALID_ID  -- <=> GetTargetLogicByStand()
    self.study_level                 = 0
    self.condep_terms                = {}
end
-- 对应 SkillCore_T::InstanceSkill 里的 `rSkillInfoOut = *pSkillInstance`
function SkillInfo:CopyFrom(inst, tmpl)
    self.skill_id                     = inst.skill_id or tmpl.id
    self.logic_id                     = inst.logic_id
    self.skill_type                   = inst.skill_type
    self.delay_time                   = inst.delay_time or 0
    self.cooldown_id                  = inst.cooldown_id or 0
    self.cooldown_time                = inst.cooldown_time or 0
    self.play_action_time             = inst.play_action_time or 0
    self.charge_time                  = inst.charge_time or 0
    self.channel_time                 = inst.channel_time or 0
    self.targeting_logic              = inst.targeting_logic
    self.select_type                  = inst.select_type or tmpl.select_type
    self.target_check_by_obj_type     = inst.target_check_by_obj_type or -1
    self.target_must_in_special_state = inst.target_must_in_special_state
    self.accuracy                     = inst.accuracy or 0
    self.critical_rate                = inst.critical_rate or 0
    self.must_use_weapon_flag         = inst.must_use_weapon_flag or tmpl.must_use_weapon or false
    self.charges_or_interval          = inst.charges_or_interval or 0
    self.ae_radius                    = inst.ae_radius or 0.0
    self.impact_id                    = inst.impact_id or C.INVALID_ID
    self.tick_impact_id               = inst.tick_impact_id or C.INVALID_ID
    self.auto_shot                    = tmpl.is_auto_shot_skill or false
    self.stand_flag                   = tmpl.stand_flag or 0
    -- GetTargetLogicByStand(): 0=要求友方, 1=要求敌方, -1=无要求
    if self.stand_flag < 0 then
        self.target_logic_by_stand = 1
    elseif self.stand_flag > 0 then
        self.target_logic_by_stand = 0
    else
        self.target_logic_by_stand = -1
    end
    self.study_level                  = inst.study_level or 0
    self.condep_terms                 = inst.condep_terms or {}
end
Data.SkillInfo = SkillInfo

--------------------------------------------------------------------------------
-- SkillTemplateData_T（技能模板）
--------------------------------------------------------------------------------
local Template = class("SkillTemplateData_T")
function Template:_init(t)
    for k, v in pairs(t) do self[k] = v end
    self.skill_instance_ids = self.skill_instance_ids or {}
end
function Template:GetSkillInstance(levelIndex)
    -- C++: pSkillTemplate->GetSkillInstance(nLevel - 1)
    return self.skill_instance_ids[levelIndex + 1]
end
function Template:GetSkillID() return self.id end
function Template:IsAutoShotSkill() return self.is_auto_shot_skill == true end
function Template:CanInterruptAutoShot() return self.can_interrupt_auto_shot ~= 0 and true or false end
function Template:GetSelectType() return self.select_type end
function Template:GetStandFlag() return self.stand_flag or 0 end
function Template:GetClassByUser() return self.class_by_user end
function Template:GetTargetMustInSpecialState() return self.target_must_in_special_state end
Data.SkillTemplateData_T = Template

--------------------------------------------------------------------------------
-- SkillInstanceData_T（按等级实例化的技能数据）
--------------------------------------------------------------------------------
local Instance = class("SkillInstanceData_T")
function Instance:_init(t)
    for k, v in pairs(t) do self[k] = v end
end
Data.SkillInstanceData_T = Instance

--------------------------------------------------------------------------------
-- 管理器
--------------------------------------------------------------------------------
local Mgr = class("DataMgr")
function Mgr:_init() self._byID = {} end
function Mgr:Add(obj) self._byID[obj.id] = obj end
function Mgr:GetInstanceByID(id) return self._byID[id] end

Data.g_SkillTemplateDataMgr = Mgr.new()
Data.g_SkillInstanceDataMgr = Mgr.new()

--------------------------------------------------------------------------------
-- 场景 / 对象容器
--------------------------------------------------------------------------------
local ObjMgr = class("ObjMgr")
function ObjMgr:_init() self._byID = {}; self._order = {} end
function ObjMgr:Add(obj)
    self._byID[obj:GetID()] = obj
    table.insert(self._order, obj)
end
function ObjMgr:GetObj(id) return self._byID[id] end
function ObjMgr:GetAll() return self._order end
Data.ObjMgr = ObjMgr

local Scene = class("Scene")
function Scene:_init(id)
    self.id = id
    self.m_ThreadID = 1
    self._objmgr = ObjMgr.new()
    self._event_core = {}
end
function Scene:SceneID() return self.id end
function Scene:GetObjManager() return self._objmgr end
function Scene:GetEventCore() return self._event_core end
Data.Scene = Scene

--------------------------------------------------------------------------------
-- 示例技能数据注册
--------------------------------------------------------------------------------
local function def_skill(tmpl, instances)
    local t = Template.new(tmpl)
    t.skill_instance_ids = {}
    for _, inst in ipairs(instances) do
        inst.id       = tmpl.id * 100 + inst.level      -- 实例 ID，例如 100101
        inst.skill_id = tmpl.id
        local o = Instance.new(inst)
        Data.g_SkillInstanceDataMgr:Add(o)
        table.insert(t.skill_instance_ids, o.id)
    end
    Data.g_SkillTemplateDataMgr:Add(t)
end

-- 1001 烈焰弹：瞬发单体，带消耗与冷却
def_skill({
    id = 1001, name = "烈焰弹", menpai = 0, skill_class = 1, class_by_user = 0,
    passive_flag = 0, select_type = C.SELECT_TYPE.CHARACTER, stand_flag = -1,
    is_auto_shot_skill = false, can_interrupt_auto_shot = 1, must_use_weapon = false,
    target_must_in_special_state = 0,
}, {
    { level = 1, logic_id = 1, skill_type = C.SKILL_INSTANT_LAUNCHING,
      delay_time = 100, cooldown_id = 101, cooldown_time = 1500, play_action_time = 800,
      targeting_logic = C.TARGET_LOGIC.SPECIFIC_UNIT, select_type = C.SELECT_TYPE.CHARACTER,
      target_check_by_obj_type = -1, target_must_in_special_state = 0,
      accuracy = 100, critical_rate = 20, charges_or_interval = 1,
      impact_id = 5001, condep_terms = { { kind = "mp", value = 30 } } },
})

-- 1002 三连斩：charges_or_interval = 3，演示 ActivateOnce 循环
def_skill({
    id = 1002, name = "三连斩", menpai = 0, skill_class = 1, class_by_user = 0,
    passive_flag = 0, select_type = C.SELECT_TYPE.CHARACTER, stand_flag = -1,
    is_auto_shot_skill = false, can_interrupt_auto_shot = 1, must_use_weapon = false,
    target_must_in_special_state = 0,
}, {
    { level = 1, logic_id = 1, skill_type = C.SKILL_INSTANT_LAUNCHING,
      delay_time = 80, cooldown_id = 102, cooldown_time = 2000, play_action_time = 600,
      targeting_logic = C.TARGET_LOGIC.SPECIFIC_UNIT, select_type = C.SELECT_TYPE.CHARACTER,
      target_check_by_obj_type = -1, target_must_in_special_state = 0,
      accuracy = 95, critical_rate = 15, charges_or_interval = 3,
      impact_id = 5001, condep_terms = { { kind = "mp", value = 15 } } },
})

-- 1003 聚气术：GATHER，演示 StartCharging 注册充能动作
def_skill({
    id = 1003, name = "聚气术", menpai = 0, skill_class = 1, class_by_user = 0,
    passive_flag = 0, select_type = C.SELECT_TYPE.SELF, stand_flag = -1,
    is_auto_shot_skill = false, can_interrupt_auto_shot = 1, must_use_weapon = false,
    target_must_in_special_state = -1,
}, {
    { level = 1, logic_id = 1, skill_type = C.SKILL_NEED_CHARGING,
      charge_time = 2000, cooldown_id = 103, cooldown_time = 3000, play_action_time = 500,
      targeting_logic = C.TARGET_LOGIC.AE_AROUND_SELF, ae_radius = 5.0,
      select_type = C.SELECT_TYPE.SELF, target_check_by_obj_type = -1,
      target_must_in_special_state = -1, accuracy = 100, critical_rate = 0,
      charges_or_interval = 1, impact_id = 5002,
      condep_terms = { { kind = "mp", value = 50 } } },
})

-- 1004 引导箭：LEAD，演示 StartChanneling + 心跳
def_skill({
    id = 1004, name = "引导箭", menpai = 0, skill_class = 1, class_by_user = 0,
    passive_flag = 0, select_type = C.SELECT_TYPE.CHARACTER, stand_flag = -1,
    is_auto_shot_skill = false, can_interrupt_auto_shot = 1, must_use_weapon = false,
    target_must_in_special_state = 0,
}, {
    { level = 1, logic_id = 1, skill_type = C.SKILL_NEED_CHANNELING,
      channel_time = 3000, cooldown_id = 104, cooldown_time = 1000, play_action_time = 400,
      targeting_logic = C.TARGET_LOGIC.SPECIFIC_UNIT, select_type = C.SELECT_TYPE.CHARACTER,
      target_check_by_obj_type = -1, target_must_in_special_state = 0,
      accuracy = 100, critical_rate = 10, charges_or_interval = 1000,
      impact_id = 5003, tick_impact_id = 5003, condep_terms = { { kind = "mp", value = 20 } } },
})

-- 1005 火雨：AE，演示 TARGET_AE_AROUND_POSITION
def_skill({
    id = 1005, name = "火雨", menpai = 0, skill_class = 1, class_by_user = 0,
    passive_flag = 0, select_type = C.SELECT_TYPE.POS, stand_flag = -1,
    is_auto_shot_skill = false, can_interrupt_auto_shot = 1, must_use_weapon = false,
    target_must_in_special_state = -1,
}, {
    { level = 1, logic_id = 1, skill_type = C.SKILL_INSTANT_LAUNCHING,
      delay_time = 200, cooldown_id = 105, cooldown_time = 4000, play_action_time = 1000,
      targeting_logic = C.TARGET_LOGIC.AE_AROUND_POSITION, ae_radius = 6.0,
      select_type = C.SELECT_TYPE.POS, target_check_by_obj_type = -1,
      target_must_in_special_state = -1, accuracy = 100, critical_rate = 5,
      charges_or_interval = 1, impact_id = 5002,
      condep_terms = { { kind = "mp", value = 80 } } },
})

-- 1006 连射：自动连发技能，走 m_nAutoShotSkill 通道
def_skill({
    id = 1006, name = "连射", menpai = 0, skill_class = 1, class_by_user = 0,
    passive_flag = 0, select_type = C.SELECT_TYPE.CHARACTER, stand_flag = -1,
    is_auto_shot_skill = true, can_interrupt_auto_shot = 1, must_use_weapon = false,
    target_must_in_special_state = 0,
}, {
    { level = 1, logic_id = 1, skill_type = C.SKILL_INSTANT_LAUNCHING,
      delay_time = 50, cooldown_id = 106, cooldown_time = 500, play_action_time = 300,
      targeting_logic = C.TARGET_LOGIC.SPECIFIC_UNIT, select_type = C.SELECT_TYPE.CHARACTER,
      target_check_by_obj_type = -1, target_must_in_special_state = 0,
      accuracy = 100, critical_rate = 10, charges_or_interval = 1,
      impact_id = 5001, condep_terms = { { kind = "mp", value = 5 } } },
})

-- 1007 治疗术：stand_flag = 1（正面技能，需同阵营）
def_skill({
    id = 1007, name = "治疗术", menpai = 0, skill_class = 1, class_by_user = 0,
    passive_flag = 0, select_type = C.SELECT_TYPE.CHARACTER, stand_flag = 1,
    is_auto_shot_skill = false, can_interrupt_auto_shot = 1, must_use_weapon = false,
    target_must_in_special_state = 0,
}, {
    { level = 1, logic_id = 1, skill_type = C.SKILL_INSTANT_LAUNCHING,
      delay_time = 0, cooldown_id = 107, cooldown_time = 2000, play_action_time = 700,
      targeting_logic = C.TARGET_LOGIC.SPECIFIC_UNIT, select_type = C.SELECT_TYPE.CHARACTER,
      target_check_by_obj_type = -1, target_must_in_special_state = 0,
      accuracy = 100, critical_rate = 0, charges_or_interval = 1,
      impact_id = 5004, condep_terms = { { kind = "mp", value = 40 } } },
})

return Data
