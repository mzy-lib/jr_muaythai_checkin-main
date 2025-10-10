-- 修复额外签到验证触发器
-- 创建于: 2025-03-02
-- 作者: Claude AI
-- 描述: 此脚本创建一个触发器，用于在签到记录创建时验证签到有效性并标记额外签到

BEGIN;

-- 检查validate_check_in触发器是否已注册
DO $$
DECLARE
    v_trigger_exists BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM information_schema.triggers 
        WHERE event_object_table = 'check_ins' 
        AND trigger_name = 'validate_check_in_trigger'
    ) INTO v_trigger_exists;
    
    IF v_trigger_exists THEN
        RAISE NOTICE '触发器validate_check_in_trigger已存在，将被重新创建';
    ELSE
        RAISE NOTICE '触发器validate_check_in_trigger不存在，将被创建';
    END IF;
END $$;

-- 删除已存在的触发器（如果有）
DROP TRIGGER IF EXISTS validate_check_in_trigger ON check_ins;

-- 创建新的触发器
CREATE TRIGGER validate_check_in_trigger
BEFORE INSERT ON check_ins
FOR EACH ROW
EXECUTE FUNCTION validate_check_in();

-- 记录触发器创建
INSERT INTO debug_logs (function_name, message, details)
VALUES (
    'fix_validate_check_in_trigger',
    '创建validate_check_in触发器',
    jsonb_build_object(
        'timestamp', NOW(),
        'trigger_name', 'validate_check_in_trigger',
        'table', 'check_ins',
        'event', 'BEFORE INSERT'
    )
);

-- 检查触发器执行顺序
DO $$
DECLARE
    v_triggers RECORD;
BEGIN
    RAISE NOTICE '检查check_ins表上的触发器执行顺序：';
    
    FOR v_triggers IN (
        SELECT trigger_name, action_timing, event_manipulation
        FROM information_schema.triggers
        WHERE event_object_table = 'check_ins'
        ORDER BY action_order
    ) LOOP
        RAISE NOTICE '%: % %', v_triggers.trigger_name, v_triggers.action_timing, v_triggers.event_manipulation;
    END LOOP;
END $$;

-- 添加测试函数，用于验证触发器是否正常工作
CREATE OR REPLACE FUNCTION test_validate_check_in_trigger()
RETURNS VOID AS $$
DECLARE
    v_member_id UUID;
    v_card_id UUID;
    v_check_in_id UUID;
    v_is_extra BOOLEAN;
    v_test_date DATE := CURRENT_DATE + INTERVAL '1 day'; -- 使用明天的日期避免重复签到
BEGIN
    -- 创建测试会员
    INSERT INTO members (id, name, email, is_new_member)
    VALUES (gen_random_uuid(), '触发器测试会员', 'trigger_test@example.com', true)
    RETURNING id INTO v_member_id;
    
    -- 记录开始测试
    INSERT INTO debug_logs (function_name, message, details)
    VALUES (
        'test_validate_check_in_trigger',
        '开始测试validate_check_in触发器',
        jsonb_build_object(
            'timestamp', NOW(),
            'member_id', v_member_id,
            'test_date', v_test_date
        )
    );
    
    -- 创建签到记录（新会员，无会员卡）
    INSERT INTO check_ins (id, member_id, check_in_date, class_type, is_private, time_slot)
    VALUES (gen_random_uuid(), v_member_id, v_test_date, 'morning', false, '09:00-10:30')
    RETURNING id, is_extra INTO v_check_in_id, v_is_extra;
    
    -- 记录测试结果
    INSERT INTO debug_logs (function_name, message, details)
    VALUES (
        'test_validate_check_in_trigger',
        '新会员签到测试结果',
        jsonb_build_object(
            'timestamp', NOW(),
            'member_id', v_member_id,
            'check_in_id', v_check_in_id,
            'is_extra', v_is_extra,
            'expected_is_extra', true,
            'test_passed', v_is_extra = true
        )
    );
    
    -- 创建过期会员卡
    INSERT INTO membership_cards (id, member_id, card_type, card_category, card_subtype, valid_until, remaining_group_sessions)
    VALUES (gen_random_uuid(), v_member_id, 'group', 'session', 'ten_sessions', v_test_date - INTERVAL '1 day', 5)
    RETURNING id INTO v_card_id;
    
    -- 创建签到记录（使用过期会员卡）
    INSERT INTO check_ins (id, member_id, card_id, check_in_date, class_type, is_private, time_slot)
    VALUES (gen_random_uuid(), v_member_id, v_card_id, v_test_date, 'evening', false, '17:00-18:30')
    RETURNING id, is_extra INTO v_check_in_id, v_is_extra;
    
    -- 记录测试结果
    INSERT INTO debug_logs (function_name, message, details)
    VALUES (
        'test_validate_check_in_trigger',
        '过期会员卡签到测试结果',
        jsonb_build_object(
            'timestamp', NOW(),
            'member_id', v_member_id,
            'card_id', v_card_id,
            'check_in_id', v_check_in_id,
            'is_extra', v_is_extra,
            'expected_is_extra', true,
            'test_passed', v_is_extra = true
        )
    );
    
    -- 清理测试数据
    DELETE FROM check_ins WHERE member_id = v_member_id;
    DELETE FROM membership_cards WHERE member_id = v_member_id;
    DELETE FROM members WHERE id = v_member_id;
    
    -- 记录测试完成
    INSERT INTO debug_logs (function_name, message, details)
    VALUES (
        'test_validate_check_in_trigger',
        '完成测试validate_check_in触发器',
        jsonb_build_object(
            'timestamp', NOW()
        )
    );
END;
$$ LANGUAGE plpgsql;

-- 执行测试函数
SELECT test_validate_check_in_trigger();

-- 授予函数执行权限
GRANT EXECUTE ON FUNCTION test_validate_check_in_trigger() TO postgres, anon, authenticated, service_role;

COMMIT; 