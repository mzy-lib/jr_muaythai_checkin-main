-- 修复validate_check_in函数中的过期会员卡检测逻辑
-- 创建于: 2025-03-02
-- 作者: Claude AI
-- 描述: 此脚本修复validate_check_in函数中的过期会员卡检测逻辑，确保过期会员卡签到被正确标记为额外签到

BEGIN;

-- 记录开始修复
INSERT INTO debug_logs (function_name, message, details)
VALUES (
    'fix_validate_check_in_function',
    '开始修复validate_check_in函数',
    jsonb_build_object(
        'timestamp', NOW(),
        'issue', '过期会员卡检测逻辑错误',
        'description', '过期会员卡签到未被正确标记为额外签到'
    )
);

-- 创建或替换validate_check_in函数
CREATE OR REPLACE FUNCTION validate_check_in()
RETURNS trigger AS $$
DECLARE
  v_member RECORD;
  v_card RECORD;
  v_daily_check_ins integer;
  v_has_same_class_check_in boolean;
BEGIN
  -- 检查会员是否存在
  IF NOT check_member_exists(NEW.member_id) THEN
    RAISE EXCEPTION '会员不存在
Member not found';
  END IF;

  -- 检查是否重复签到
  IF check_duplicate_check_in(NEW.member_id, NEW.check_in_date, NEW.class_type::TEXT) THEN
    RAISE EXCEPTION '今天已经签到过这个时段的课程。
Already checked in for this time slot today.';
  END IF;

  -- 处理会员卡验证
  IF NEW.card_id IS NOT NULL THEN
    -- 只锁定会员卡记录，使用SKIP LOCKED避免等待
    SELECT * INTO v_card
    FROM membership_cards
    WHERE id = NEW.card_id
    FOR UPDATE SKIP LOCKED;

    IF NOT FOUND THEN
      RAISE EXCEPTION '会员卡不存在
Membership card not found';
    END IF;

    -- 严格验证会员卡与会员的关联
    IF v_card.member_id != NEW.member_id THEN
      RAISE EXCEPTION '会员卡不属于该会员
Membership card does not belong to this member';
    END IF;

    -- 记录会员卡验证开始
    INSERT INTO debug_logs (function_name, message, details)
    VALUES ('validate_check_in', '开始会员卡验证',
      jsonb_build_object(
        'card_id', NEW.card_id,
        'member_id', NEW.member_id,
        'check_in_date', NEW.check_in_date,
        'valid_until', v_card.valid_until
      )
    );

    -- 检查会员卡是否过期
    IF v_card.valid_until IS NOT NULL AND v_card.valid_until < NEW.check_in_date THEN
      -- 记录会员卡过期
      INSERT INTO debug_logs (function_name, message, details)
      VALUES ('validate_check_in', '会员卡已过期',
        jsonb_build_object(
          'card_id', NEW.card_id,
          'valid_until', v_card.valid_until,
          'check_in_date', NEW.check_in_date
        )
      );
      
      -- 标记为额外签到
      NEW.is_extra := true;
      
      -- 记录额外签到原因
      INSERT INTO debug_logs (function_name, message, details)
      VALUES ('validate_check_in', '额外签到原因',
        jsonb_build_object(
          'card_id', NEW.card_id,
          'reason', '会员卡已过期',
          'check_details', jsonb_build_object(
            'member_id', NEW.member_id,
            'class_type', NEW.class_type,
            'check_in_date', NEW.check_in_date,
            'card_type', v_card.card_type,
            'card_category', v_card.card_category,
            'card_subtype', v_card.card_subtype,
            'valid_until', v_card.valid_until
          )
        )
      );
    ELSE
      -- 使用CASE表达式简化条件判断
      NEW.is_extra := CASE
        -- 卡类型不匹配
        WHEN (v_card.card_type = 'group' AND NEW.class_type::TEXT = 'private') OR
             (v_card.card_type = 'private' AND NEW.class_type::TEXT != 'private') THEN true
        -- 团课课时卡课时不足
        WHEN v_card.card_type = 'group' AND v_card.card_category = 'session' AND
             (v_card.remaining_group_sessions IS NULL OR v_card.remaining_group_sessions <= 0) THEN true
        -- 私教课时不足
        WHEN v_card.card_type = 'private' AND
             (v_card.remaining_private_sessions IS NULL OR v_card.remaining_private_sessions <= 0) THEN true
        -- 月卡超出每日限制
        WHEN v_card.card_type = 'group' AND v_card.card_category = 'monthly' THEN
          CASE
            WHEN v_card.card_subtype = 'single_monthly' AND
                 (SELECT COUNT(*) FROM check_ins
                  WHERE member_id = NEW.member_id
                  AND check_in_date = NEW.check_in_date
                  AND id IS DISTINCT FROM NEW.id
                  AND NOT is_extra) >= 1 THEN true
            WHEN v_card.card_subtype = 'double_monthly' AND
                 (SELECT COUNT(*) FROM check_ins
                  WHERE member_id = NEW.member_id
                  AND check_in_date = NEW.check_in_date
                  AND id IS DISTINCT FROM NEW.id
                  AND NOT is_extra) >= 2 THEN true
            ELSE false
          END
        -- 其他情况为正常签到
        ELSE false
      END;

      -- 记录额外签到原因
      IF NEW.is_extra THEN
        INSERT INTO debug_logs (function_name, message, details)
        VALUES ('validate_check_in', '额外签到原因',
          jsonb_build_object(
            'card_id', NEW.card_id,
            'reason', CASE
              WHEN (v_card.card_type = 'group' AND NEW.class_type::TEXT = 'private') OR
                   (v_card.card_type = 'private' AND NEW.class_type::TEXT != 'private') THEN '卡类型不匹配'
              WHEN v_card.card_type = 'group' AND v_card.card_category = 'session' AND
                   (v_card.remaining_group_sessions IS NULL OR v_card.remaining_group_sessions <= 0) THEN '团课课时不足'
              WHEN v_card.card_type = 'private' AND
                   (v_card.remaining_private_sessions IS NULL OR v_card.remaining_private_sessions <= 0) THEN '私教课时不足'
              WHEN v_card.card_type = 'group' AND v_card.card_category = 'monthly' THEN '月卡超出每日限制'
              ELSE '未知原因'
            END,
            'check_details', jsonb_build_object(
              'member_id', NEW.member_id,
              'class_type', NEW.class_type,
              'check_in_date', NEW.check_in_date,
              'card_type', v_card.card_type,
              'card_category', v_card.card_category,
              'card_subtype', v_card.card_subtype,
              'valid_until', v_card.valid_until,
              'remaining_group_sessions', v_card.remaining_group_sessions,
              'remaining_private_sessions', v_card.remaining_private_sessions
            )
          )
        );
      END IF;
    END IF;
  ELSE
    -- 无会员卡时为额外签到
    NEW.is_extra := true;

    -- 记录额外签到原因
    INSERT INTO debug_logs (function_name, message, details)
    VALUES ('validate_check_in', '额外签到原因',
      jsonb_build_object(
        'reason', '未指定会员卡',
        'check_details', jsonb_build_object(
          'member_id', NEW.member_id,
          'class_type', NEW.class_type,
          'check_in_date', NEW.check_in_date
        )
      )
    );
  END IF;

  -- 记录详细日志
  INSERT INTO debug_logs (function_name, member_id, message, details)
  VALUES ('validate_check_in', NEW.member_id,
    '会员卡验证结果',
    jsonb_build_object(
      'card_id', NEW.card_id,
      'check_details', jsonb_build_object(
        'member_id', NEW.member_id,
        'class_type', NEW.class_type,
        'check_in_date', NEW.check_in_date
      ),
      'has_valid_card', NEW.card_id IS NOT NULL AND NOT NEW.is_extra,
      'card_belongs_to_member', CASE WHEN NEW.card_id IS NOT NULL THEN
        (SELECT member_id FROM membership_cards WHERE id = NEW.card_id) = NEW.member_id
        ELSE NULL END
    )
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 记录修复完成
INSERT INTO debug_logs (function_name, message, details)
VALUES (
    'fix_validate_check_in_function',
    '完成修复validate_check_in函数',
    jsonb_build_object(
        'timestamp', NOW(),
        'changes', '分离过期会员卡检测逻辑，确保过期会员卡签到被正确标记为额外签到'
    )
);

-- 添加测试函数，用于验证修复后的函数是否正常工作
CREATE OR REPLACE FUNCTION test_expired_card_validation()
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
    VALUES (gen_random_uuid(), '过期卡测试会员', 'expired_card_test@example.com', false)
    RETURNING id INTO v_member_id;
    
    -- 记录开始测试
    INSERT INTO debug_logs (function_name, message, details)
    VALUES (
        'test_expired_card_validation',
        '开始测试过期会员卡验证',
        jsonb_build_object(
            'timestamp', NOW(),
            'member_id', v_member_id,
            'test_date', v_test_date
        )
    );
    
    -- 创建过期会员卡
    INSERT INTO membership_cards (id, member_id, card_type, card_category, card_subtype, valid_until, remaining_group_sessions)
    VALUES (gen_random_uuid(), v_member_id, 'group', 'session', 'ten_sessions', v_test_date - INTERVAL '1 day', 5)
    RETURNING id INTO v_card_id;
    
    -- 创建签到记录（使用过期会员卡）
    INSERT INTO check_ins (id, member_id, card_id, check_in_date, class_type, is_private, time_slot)
    VALUES (gen_random_uuid(), v_member_id, v_card_id, v_test_date, 'morning', false, '09:00-10:30')
    RETURNING id, is_extra INTO v_check_in_id, v_is_extra;
    
    -- 记录测试结果
    INSERT INTO debug_logs (function_name, message, details)
    VALUES (
        'test_expired_card_validation',
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
        'test_expired_card_validation',
        '完成测试过期会员卡验证',
        jsonb_build_object(
            'timestamp', NOW()
        )
    );
END;
$$ LANGUAGE plpgsql;

-- 执行测试函数
SELECT test_expired_card_validation();

-- 授予函数执行权限
GRANT EXECUTE ON FUNCTION validate_check_in() TO postgres, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION test_expired_card_validation() TO postgres, anon, authenticated, service_role;

COMMIT; 