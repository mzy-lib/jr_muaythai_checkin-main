-- 修复额外签到验证函数和测试数据问题
-- 文件名: fix_validate_check_in_function_v3.sql
-- 描述: 修复测试数据问题，确保测试中创建的会员卡具有正确的valid_until值

BEGIN;

-- 记录修复开始
INSERT INTO debug_logs (function_name, message, details)
VALUES ('fix_validate_check_in_function_v3', '开始修复测试数据问题', 
  jsonb_build_object(
    'issue', '测试数据问题',
    'description', '测试中创建的会员卡的valid_until字段为NULL，导致过期检测失败'
  )
);

-- 创建或替换测试函数，确保创建的会员卡具有正确的valid_until值
CREATE OR REPLACE FUNCTION test_expired_card_validation_v3()
RETURNS void AS $$
DECLARE
  v_test_member_id UUID;
  v_test_card_id UUID;
  v_test_checkin_id UUID;
  v_test_date DATE := CURRENT_DATE;
  v_expired_date DATE := CURRENT_DATE - INTERVAL '1 day'; -- 设置为昨天，确保过期
  v_is_extra BOOLEAN;
BEGIN
  -- 记录测试开始
  INSERT INTO debug_logs (function_name, message, details)
  VALUES ('test_expired_card_validation_v3', '开始测试过期会员卡验证', 
    jsonb_build_object(
      'test_date', v_test_date,
      'expired_date', v_expired_date,
      'timestamp', now()
    )
  );

  -- 创建测试会员
  INSERT INTO members (id, name, email, phone, status, created_at, updated_at, extra_check_ins)
  VALUES (
    gen_random_uuid(),
    '测试过期卡会员V3',
    'test_expired_v3@example.com',
    '13800138003',
    'active',
    now(),
    now(),
    0
  )
  RETURNING id INTO v_test_member_id;

  -- 创建过期会员卡（明确设置valid_until为昨天）
  INSERT INTO membership_cards (
    id, 
    member_id, 
    card_type, 
    card_category, 
    card_subtype, 
    trainer_type, 
    remaining_group_sessions, 
    remaining_private_sessions, 
    valid_until, 
    created_at
  )
  VALUES (
    gen_random_uuid(),
    v_test_member_id,
    'sessions',
    'standard',
    'regular',
    'junior',
    0,
    0,
    v_expired_date, -- 明确设置为昨天，确保过期
    now()
  )
  RETURNING id INTO v_test_card_id;

  -- 记录创建的过期会员卡
  INSERT INTO debug_logs (function_name, message, details)
  VALUES ('test_expired_card_validation_v3', '创建过期会员卡', 
    jsonb_build_object(
      'card_id', v_test_card_id,
      'member_id', v_test_member_id,
      'valid_until', v_expired_date,
      'current_date', v_test_date
    )
  );

  -- 使用过期会员卡创建签到记录
  INSERT INTO check_ins (
    id,
    member_id,
    card_id,
    check_in_date,
    class_type,
    is_private,
    time_slot
  )
  VALUES (
    gen_random_uuid(),
    v_test_member_id,
    v_test_card_id,
    v_test_date,
    'group',
    false,
    '18:00-19:00'
  )
  RETURNING id, is_extra INTO v_test_checkin_id, v_is_extra;

  -- 验证签到是否被标记为额外签到
  INSERT INTO debug_logs (function_name, message, details)
  VALUES ('test_expired_card_validation_v3', '过期卡签到测试结果', 
    jsonb_build_object(
      'checkin_id', v_test_checkin_id,
      'is_extra', v_is_extra,
      'expected_is_extra', true,
      'test_passed', v_is_extra = true,
      'card_id', v_test_card_id,
      'valid_until', v_expired_date,
      'check_in_date', v_test_date
    )
  );

  -- 记录测试完成
  INSERT INTO debug_logs (function_name, message, details)
  VALUES ('test_expired_card_validation_v3', '完成测试过期会员卡验证', jsonb_build_object());

END;
$$ LANGUAGE plpgsql;

-- 授予执行权限
GRANT EXECUTE ON FUNCTION test_expired_card_validation_v3() TO PUBLIC;

-- 执行测试函数
SELECT test_expired_card_validation_v3();

-- 记录修复完成
INSERT INTO debug_logs (function_name, message, details)
VALUES ('fix_validate_check_in_function_v3', '完成修复测试数据问题', 
  jsonb_build_object(
    'changes', '确保测试中创建的会员卡具有正确的valid_until值，以便正确测试过期检测逻辑'
  )
);

COMMIT; 