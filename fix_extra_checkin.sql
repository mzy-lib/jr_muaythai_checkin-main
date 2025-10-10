-- 修复额外签到场景中的问题

-- 1. 修改deduct_membership_sessions函数，防止课时变为负数
CREATE OR REPLACE FUNCTION deduct_membership_sessions(p_card_id UUID, p_class_type TEXT, p_is_private BOOLEAN DEFAULT false)
RETURNS void
LANGUAGE plpgsql
AS $function$
DECLARE
  v_card RECORD;
BEGIN
  -- 获取会员卡信息
  SELECT * INTO v_card FROM membership_cards WHERE id = p_card_id;
  
  -- 记录开始扣除课时
  INSERT INTO debug_logs (function_name, message, details)
  VALUES ('deduct_membership_sessions', '扣除课时开始',
    jsonb_build_object(
      'card_id', p_card_id,
      'card_type', v_card.card_type,
      'class_type', p_class_type,
      'is_private', p_is_private,
      'card_subtype', v_card.card_subtype,
      'card_category', v_card.card_category,
      'remaining_group_sessions', v_card.remaining_group_sessions,
      'remaining_private_sessions', v_card.remaining_private_sessions
    )
  );
  
  -- 检查会员卡是否已过期
  IF v_card.valid_until IS NOT NULL AND v_card.valid_until < CURRENT_DATE THEN
    INSERT INTO debug_logs (function_name, message, details)
    VALUES ('deduct_membership_sessions', '会员卡已过期，不扣除课时',
      jsonb_build_object(
        'card_id', p_card_id,
        'valid_until', v_card.valid_until,
        'current_date', CURRENT_DATE
      )
    );
    RETURN;
  END IF;
  
  -- 私教课程
  IF p_is_private AND v_card.card_type = 'private' THEN
    -- 检查剩余私教课时
    IF v_card.remaining_private_sessions IS NULL OR v_card.remaining_private_sessions <= 0 THEN
      INSERT INTO debug_logs (function_name, message, details)
      VALUES ('deduct_membership_sessions', '私教课时不足，不扣除',
        jsonb_build_object(
          'card_id', p_card_id,
          'remaining_private_sessions', v_card.remaining_private_sessions
        )
      );
      RETURN;
    END IF;
    
    -- 扣除私教课时
    UPDATE membership_cards
    SET remaining_private_sessions = remaining_private_sessions - 1
    WHERE id = p_card_id;
    
    -- 记录私教课时扣除
    INSERT INTO debug_logs (function_name, message, details)
    VALUES ('deduct_membership_sessions', '私教课时已扣除',
      jsonb_build_object(
        'card_id', p_card_id,
        'remaining_private_sessions', v_card.remaining_private_sessions - 1
      )
    );
  -- 团课课程
  ELSIF NOT p_is_private AND p_class_type IN ('morning', 'evening') AND 
        (v_card.card_type = 'group' OR v_card.card_type = 'class') AND 
        (v_card.card_category = 'session' OR v_card.card_category = 'group') THEN
    -- 检查剩余团课课时
    IF v_card.remaining_group_sessions IS NULL OR v_card.remaining_group_sessions <= 0 THEN
      INSERT INTO debug_logs (function_name, message, details)
      VALUES ('deduct_membership_sessions', '团课课时不足，不扣除',
        jsonb_build_object(
          'card_id', p_card_id,
          'remaining_group_sessions', v_card.remaining_group_sessions
        )
      );
      RETURN;
    END IF;
    
    -- 扣除团课课时
    UPDATE membership_cards
    SET remaining_group_sessions = remaining_group_sessions - 1
    WHERE id = p_card_id;
    
    -- 记录团课课时扣除
    INSERT INTO debug_logs (function_name, message, details)
    VALUES ('deduct_membership_sessions', '团课课时已扣除',
      jsonb_build_object(
        'card_id', p_card_id,
        'remaining_group_sessions', v_card.remaining_group_sessions - 1
      )
    );
  ELSE
    -- 记录未扣除课时的原因
    INSERT INTO debug_logs (function_name, message, details)
    VALUES ('deduct_membership_sessions', '未扣除课时',
      jsonb_build_object(
        'reason', '卡类型与课程类型不匹配',
        'card_id', p_card_id,
        'card_type', v_card.card_type,
        'card_category', v_card.card_category,
        'class_type', p_class_type,
        'is_private', p_is_private
      )
    );
  END IF;
END;
$function$;

-- 授予函数执行权限
GRANT EXECUTE ON FUNCTION deduct_membership_sessions(UUID, TEXT, BOOLEAN) TO anon, authenticated, service_role;

-- 2. 修改validate_check_in函数，增强对无效会员卡的检测
CREATE OR REPLACE FUNCTION validate_check_in()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
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
    RAISE EXCEPTION '今天已经在这个时段签到过了
Already checked in for this class type today';
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

    -- 使用CASE表达式简化条件判断
    NEW.is_extra := CASE
      -- 卡类型不匹配
      WHEN (v_card.card_type = 'group' AND NEW.class_type::TEXT = 'private') OR
           (v_card.card_type = 'private' AND NEW.class_type::TEXT != 'private') THEN true
      -- 卡已过期
      WHEN v_card.valid_until IS NOT NULL AND v_card.valid_until < NEW.check_in_date THEN true
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
            WHEN v_card.valid_until IS NOT NULL AND v_card.valid_until < NEW.check_in_date THEN '会员卡已过期'
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
$function$;

-- 授予函数执行权限
GRANT EXECUTE ON FUNCTION validate_check_in() TO anon, authenticated, service_role;

-- 3. 修改trigger_deduct_sessions函数，增加对会员卡有效性的二次检查
CREATE OR REPLACE FUNCTION trigger_deduct_sessions()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
  v_card RECORD;
BEGIN
  -- 记录触发器执行开始
  INSERT INTO debug_logs (function_name, message, details)
  VALUES ('trigger_deduct_sessions', '触发器执行开始',
    jsonb_build_object(
      'check_in_id', NEW.id,
      'member_id', NEW.member_id,
      'card_id', NEW.card_id,
      'is_extra', NEW.is_extra,
      'class_type', NEW.class_type
    )
  );

  -- 只有非额外签到且指定了会员卡才扣除课时
  IF NOT NEW.is_extra AND NEW.card_id IS NOT NULL THEN
    -- 二次检查会员卡有效性
    SELECT * INTO v_card FROM membership_cards WHERE id = NEW.card_id;
    
    -- 检查会员卡是否已过期
    IF v_card.valid_until IS NOT NULL AND v_card.valid_until < NEW.check_in_date THEN
      INSERT INTO debug_logs (function_name, message, details)
      VALUES ('trigger_deduct_sessions', '未扣除课时',
        jsonb_build_object(
          'reason', '会员卡已过期',
          'check_in_id', NEW.id,
          'card_id', NEW.card_id,
          'valid_until', v_card.valid_until,
          'check_in_date', NEW.check_in_date
        )
      );
      RETURN NULL;
    END IF;
    
    -- 检查团课课时是否足够
    IF NOT NEW.is_private AND (v_card.card_type = 'group' OR v_card.card_type = 'class') AND 
       (v_card.card_category = 'session' OR v_card.card_category = 'group') AND
       (v_card.remaining_group_sessions IS NULL OR v_card.remaining_group_sessions <= 0) THEN
      INSERT INTO debug_logs (function_name, message, details)
      VALUES ('trigger_deduct_sessions', '未扣除课时',
        jsonb_build_object(
          'reason', '团课课时不足',
          'check_in_id', NEW.id,
          'card_id', NEW.card_id,
          'remaining_group_sessions', v_card.remaining_group_sessions
        )
      );
      RETURN NULL;
    END IF;
    
    -- 检查私教课时是否足够
    IF NEW.is_private AND v_card.card_type = 'private' AND
       (v_card.remaining_private_sessions IS NULL OR v_card.remaining_private_sessions <= 0) THEN
      INSERT INTO debug_logs (function_name, message, details)
      VALUES ('trigger_deduct_sessions', '未扣除课时',
        jsonb_build_object(
          'reason', '私教课时不足',
          'check_in_id', NEW.id,
          'card_id', NEW.card_id,
          'remaining_private_sessions', v_card.remaining_private_sessions
        )
      );
      RETURN NULL;
    END IF;
    
    -- 传递is_private参数
    PERFORM deduct_membership_sessions(NEW.card_id, NEW.class_type::TEXT, NEW.is_private);
    
    -- 记录扣除课时结果
    INSERT INTO debug_logs (function_name, message, details)
    VALUES ('trigger_deduct_sessions', '扣除课时完成',
      jsonb_build_object(
        'check_in_id', NEW.id,
        'member_id', NEW.member_id,
        'card_id', NEW.card_id,
        'class_type', NEW.class_type,
        'is_private', NEW.is_private
      )
    );
  ELSE
    -- 记录未扣除课时原因
    INSERT INTO debug_logs (function_name, message, details)
    VALUES ('trigger_deduct_sessions', '未扣除课时',
      jsonb_build_object(
        'reason', CASE 
                    WHEN NEW.is_extra THEN '额外签到不扣除课时'
                    WHEN NEW.card_id IS NULL THEN '未指定会员卡'
                    ELSE '未知原因'
                  END,
        'check_in_id', NEW.id,
        'member_id', NEW.member_id,
        'is_extra', NEW.is_extra,
        'card_id', NEW.card_id
      )
    );
  END IF;

  RETURN NULL;
END;
$function$;

-- 授予函数执行权限
GRANT EXECUTE ON FUNCTION trigger_deduct_sessions() TO anon, authenticated, service_role; 