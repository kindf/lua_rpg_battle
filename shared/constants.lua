local C = {}

-- 无效值
C.INVALID_ID        = -1
C.INVALID_SKILL_ID  = -1
C.INVALID_GUID      = -1

-- OPERATE_RESULT（Common/GameDefine_Result.h）
C.OR_OK                           = 0    -- 成功
C.OR_ERROR                        = -1   -- 未知错误
C.OR_DIE                          = -2   -- 你已死亡
C.OR_INVALID_SKILL                = -3   -- 无效技能
C.OR_TARGET_DIE                   = -4   -- 目标已死亡
C.OR_LACK_MANA                    = -5   -- MANA 不足
C.OR_COOL_DOWNING                 = -6   -- 冷却未到
C.OR_NO_TARGET                    = -7   -- 没有目标
C.OR_INVALID_TARGET               = -8   -- 无效目标
C.OR_OUT_RANGE                    = -9   -- 超出范围
C.OR_BUSY                         = -17  -- 正在做其它事情
C.OR_NO_SCRIPT                    = -23
C.OR_NOT_ENOUGH_RAGE              = -25
C.OR_NOT_ENOUGH_ITEM              = -27
C.OR_LIMIT_USE_SKILL              = -37  -- 无法使用技能
C.OR_NEED_A_WEAPON                = -40  -- 需要一把武器
C.OR_NEED_HIGH_LEVEL_XINFA        = -41  -- 等级不够
C.OR_U_CANNT_DO_THIS_RIGHT_NOW    = -44  -- 你现在无法这样做
C.OR_NEED_HIGH_LEVEL              = -47

C.OR_SUCCEEDED = function(x) return x >= 0 end
C.OR_FAILED    = function(x) return x < 0 end

-- ENUM_SKILL_TYPE
C.SKILL_TYPE = { INVALID = -1, GATHER = 0, LEAD = 1, LAUNCH = 2, PASSIVE = 3, NUMBERS = 4 }
C.SKILL_NEED_CHARGING     = 0   -- SKILL_TYPE_GATHER
C.SKILL_NEED_CHANNELING   = 1   -- SKILL_TYPE_LEAD
C.SKILL_INSTANT_LAUNCHING = 2   -- SKILL_TYPE_LAUNCH
C.SKILL_PASSIVE           = 3

-- ENUM_SELECT_TYPE
C.SELECT_TYPE = { INVALID = -1, NONE = 0, CHARACTER = 1, POS = 2, DIR = 3, SELF = 4, HUMAN_GUID = 5, NUMBERS = 6 }

-- ENUM_TARGET_LOGIC
C.TARGET_LOGIC = {
    INVALID = -1,
    SELF = 0,              -- 只对自己有效
    MY_PET = 1,            -- 只对自己的宠物有效
    MY_SHADOW_GUARD = 2,
    MY_MASTER = 3,
    AE_AROUND_SELF = 4,    -- 以自己为中心，范围有效
    SPECIFIC_UNIT = 5,     -- 瞄准的对象有效
    AE_AROUND_UNIT = 6,    -- 以瞄准对象为中心，范围有效
    AE_AROUND_POSITION = 7,-- 以瞄准位置为中心，范围有效
    NUMBERS = 8,
}

-- ENUM_STATE (State.h)  注意顺序：IDLE=0, DEAD=1, ... COMBAT=6
C.ESTATE = {
    IDLE = 0, DEAD = 1, TERROR = 2,
    APPROACH = 3, SERVICE = 4, GOHOME = 5,
    COMBAT = 6, PATROL = 7, FLEE = 8,
    SIT = 9, TEAMFOLLOW = 10, STALL = 11,
}

-- ObjType (Obj.h)
C.OBJ_TYPE = { INVALID = 0, HUMAN = 1, MONSTER = 2, PET = 3, ITEM_BOX = 4, PLATFORM = 5, SPECIAL = 6 }

-- ENUM_CHARACTER_LOGIC (Obj_Character.h)
C.CHARACTER_LOGIC = { INVALID = -1, IDLE = 0, MOVE = 1, USE_SKILL = 2, USE_ABILITY = 3 }

-- 包处理返回值
C.PACKET_EXE_CONTINUE = 0
C.PACKET_EXE_ERROR    = 1

-- 行为类型
C.BEHAVIOR_TYPE = { HOSTILITY = -1, NEUTRALITY = 0, AMITY = 1 }

-- 其它
C.CONDITION_AND_DEPLETE_TERM_NUMBER = 3   -- SkillInstanceData_T::CONDITION_AND_DEPLETE_TERM_NUMBER
C.MAX_CHAR_SKILL_LEVEL              = 150
C.MELEE_ATTACK                      = -100 -- C++ 里的普攻特殊 ID（宏）

-- A_SKILL_FOR_PLAYER == 0（技能按使用者分类：0 玩家 / 1 怪物 / 2 宠物 / 3 物品）
C.CLASS_BY_USER_PLAYER = 0

return C

