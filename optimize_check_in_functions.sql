-- 删除旧函数
DROP FUNCTION IF EXISTS check_duplicate_check_in(uuid, date, text);
DROP FUNCTION IF EXISTS check_duplicate_check_in_with_time_slot;
DROP FUNCTION IF EXISTS check_card_validity(uuid, uuid, text, date);
DROP FUNCTION IF EXISTS deduct_membership_sessions(uuid, text, boolean);
DROP FUNCTION IF EXISTS deduct_membership_sessions(uuid, text);

-- 删除所有版本的handle_check_in函数
DROP FUNCTION IF EXISTS handle_check_in(uuid, text, text, uuid, text, date, text, uuid, boolean);
DROP FUNCTION IF EXISTS handle_check_in(uuid, text, text, uuid, text, date, uuid, boolean, text);

-- 合并重复的签到检查函数
CREATE OR REPLACE FUNCTION check_duplicate_check_in(
  p_member_id uuid, 
  p_date date, 
  p_class_type text,
  p_time_slot text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
  v_class_type class_type;
BEGIN
  -- 转换class_type
  BEGIN
    v_class_type := p_class_type::class_type;
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION '无效的课程类型: %', p_class_type;
  END;

  RETURN EXISTS (
    SELECT 1 FROM check_ins
    WHERE member_id = p_member_id
    AND check_in_date = p_date
    AND class_type = v_class_type
    AND (p_time_slot IS NULL OR time_slot = p_time_slot)
  );
END;
$$;

COMMENT ON FUNCTION check_duplicate_check_in IS '检查会员在指定日期是否已经签到特定类型的课程，可选择指定时间段';

-- 创建通用的日志记录函数
CREATE OR REPLACE FUNCTION log_debug(
  p_function_name text,
  p_message text,
  p_details jsonb,
  p_member_id uuid DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  IF current_setting('app.environment', true) = 'development' THEN
    INSERT INTO debug_logs (function_name, message, details, member_id)
    VALUES (p_function_name, p_message, p_details, p_member_id);
  END IF;
END;
$$;

COMMENT ON FUNCTION log_debug IS '通用的日志记录函数，简化各个函数中的日志记录代码';

-- 优化会员卡验证函数
CREATE OR REPLACE FUNCTION check_card_validity(
  p_card_id uuid, 
  p_member_id uuid, 
  p_class_type text, 
  p_check_in_date date
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_card RECORD;
  v_class_type class_type;
  v_result jsonb;
  v_is_valid boolean := TRUE;
  v_reason text := NULL;
BEGIN
  -- 转换class_type
  BEGIN
    v_class_type := p_class_type::class_type;
  EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'is_valid', FALSE,
      'reason', '无效的课程类型: ' || p_class_type
    );
  END;

  -- 获取会员卡信息
  SELECT * INTO v_card FROM membership_cards WHERE id = p_card_id;
  
  -- 检查会员卡是否存在
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'is_valid', FALSE,
      'reason', '会员卡不存在'
    );
  END IF;
  
  -- 检查会员卡是否属于该会员
  IF v_card.member_id != p_member_id THEN
    RETURN jsonb_build_object(
      'is_valid', FALSE,
      'reason', '会员卡不属于该会员'
    );
  END IF;
  
  -- 检查会员卡是否过期
  IF v_card.valid_until IS NOT NULL AND v_card.valid_until < p_check_in_date THEN
    RETURN jsonb_build_object(
      'is_valid', FALSE,
      'reason', '会员卡已过期',
      'details', jsonb_build_object(
        'valid_until', v_card.valid_until,
        'check_in_date', p_check_in_date
      )
    );
  END IF;
  
  -- 检查卡类型是否匹配课程类型
  IF (v_card.card_type = 'group' AND v_class_type = 'private') OR
     (v_card.card_type = 'private' AND v_class_type != 'private') THEN
    RETURN jsonb_build_object(
      'is_valid', FALSE,
      'reason', '卡类型不匹配课程类型',
      'details', jsonb_build_object(
        'card_type', v_card.card_type,
        'class_type', v_class_type
      )
    );
  END IF;
  
  -- 检查团课课时卡课时是否足够
  IF v_card.card_type = 'group' AND v_card.card_category = 'session' AND
     (v_card.remaining_group_sessions IS NULL OR v_card.remaining_group_sessions <= 0) THEN
    RETURN jsonb_build_object(
      'is_valid', FALSE,
      'reason', '团课课时不足',
      'details', jsonb_build_object(
        'remaining_group_sessions', v_card.remaining_group_sessions
      )
    );
  END IF;
  
  -- 检查私教课时是否足够
  IF v_card.card_type = 'private' AND
     (v_card.remaining_private_sessions IS NULL OR v_card.remaining_private_sessions <= 0) THEN
    RETURN jsonb_build_object(
      'is_valid', FALSE,
      'reason', '私教课时不足',
      'details', jsonb_build_object(
        'remaining_private_sessions', v_card.remaining_private_sessions
      )
    );
  END IF;
  
  -- 会员卡有效
  RETURN jsonb_build_object(
    'is_valid', TRUE,
    'card_info', jsonb_build_object(
      'card_id', v_card.id,
      'card_type', v_card.card_type,
      'card_category', v_card.card_category,
      'card_subtype', v_card.card_subtype,
      'valid_until', v_card.valid_until,
      'remaining_group_sessions', v_card.remaining_group_sessions,
      'remaining_private_sessions', v_card.remaining_private_sessions
    )
  );
END;
$$;

COMMENT ON FUNCTION check_card_validity IS '检查会员卡是否有效，返回详细的验证结果和原因';

-- 优化课时扣除函数，支持is_private参数
CREATE OR REPLACE FUNCTION deduct_membership_sessions(
  p_card_id uuid, 
  p_class_type text,
  p_is_private boolean DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
  v_card RECORD;
  v_class_type class_type;
  v_is_private boolean;
  v_member_id uuid;
BEGIN
  -- 转换class_type
  BEGIN
    v_class_type := p_class_type::class_type;
    -- 如果未提供is_private参数，则根据class_type推断
    v_is_private := COALESCE(p_is_private, (v_class_type = 'private'));
  EXCEPTION WHEN OTHERS THEN
    PERFORM log_debug(
      'deduct_membership_sessions', 
      '无效的课程类型', 
      jsonb_build_object('class_type', p_class_type)
    );
    RETURN FALSE;
  END;

  -- 获取会员卡信息
  SELECT * INTO v_card FROM membership_cards WHERE id = p_card_id FOR UPDATE;
  
  -- 获取会员ID
  v_member_id := v_card.member_id;
  
  -- 记录开始扣除课时
  PERFORM log_debug(
    'deduct_membership_sessions', 
    '扣除课时开始',
    jsonb_build_object(
      'card_id', p_card_id,
      'member_id', v_member_id,
      'card_type', v_card.card_type,
      'class_type', p_class_type,
      'is_private', v_is_private,
      'card_subtype', v_card.card_subtype,
      'card_category', v_card.card_category,
      'remaining_group_sessions', v_card.remaining_group_sessions,
      'remaining_private_sessions', v_card.remaining_private_sessions
    )
  );

  -- 检查会员卡是否已过期
  IF v_card.valid_until IS NOT NULL AND v_card.valid_until < CURRENT_DATE THEN
    PERFORM log_debug(
      'deduct_membership_sessions', 
      '会员卡已过期，不扣除课时',
      jsonb_build_object(
        'card_id', p_card_id,
        'member_id', v_member_id,
        'valid_until', v_card.valid_until,
        'current_date', CURRENT_DATE
      )
    );
    RETURN FALSE;
  END IF;

  -- 私教课程
  IF v_is_private AND v_card.card_type = 'private' THEN
    -- 检查剩余私教课时
    IF v_card.remaining_private_sessions IS NULL OR v_card.remaining_private_sessions <= 0 THEN
      PERFORM log_debug(
        'deduct_membership_sessions', 
        '私教课时不足，不扣除',
        jsonb_build_object(
          'card_id', p_card_id,
          'member_id', v_member_id,
          'remaining_private_sessions', v_card.remaining_private_sessions
        )
      );
      RETURN FALSE;
    END IF;

    -- 扣除私教课时
    UPDATE membership_cards
    SET remaining_private_sessions = remaining_private_sessions - 1
    WHERE id = p_card_id;

    -- 记录私教课时扣除
    PERFORM log_debug(
      'deduct_membership_sessions', 
      '私教课时已扣除',
      jsonb_build_object(
        'card_id', p_card_id,
        'member_id', v_member_id,
        'remaining_private_sessions', v_card.remaining_private_sessions - 1
      )
    );
    
    RETURN TRUE;
  -- 团课课程
  ELSIF NOT v_is_private AND v_class_type IN ('morning', 'evening') AND
        (v_card.card_type = 'group' OR v_card.card_type = 'class') AND
        (v_card.card_category = 'session' OR v_card.card_category = 'group') THEN
    -- 检查剩余团课课时
    IF v_card.remaining_group_sessions IS NULL OR v_card.remaining_group_sessions <= 0 THEN
      PERFORM log_debug(
        'deduct_membership_sessions', 
        '团课课时不足，不扣除',
        jsonb_build_object(
          'card_id', p_card_id,
          'member_id', v_member_id,
          'remaining_group_sessions', v_card.remaining_group_sessions
        )
      );
      RETURN FALSE;
    END IF;

    -- 扣除团课课时
    UPDATE membership_cards
    SET remaining_group_sessions = remaining_group_sessions - 1
    WHERE id = p_card_id;

    -- 记录团课课时扣除
    PERFORM log_debug(
      'deduct_membership_sessions', 
      '团课课时已扣除',
      jsonb_build_object(
        'card_id', p_card_id,
        'member_id', v_member_id,
        'remaining_group_sessions', v_card.remaining_group_sessions - 1
      )
    );
    
    RETURN TRUE;
  ELSE
    -- 记录未扣除课时的原因
    PERFORM log_debug(
      'deduct_membership_sessions', 
      '未扣除课时',
      jsonb_build_object(
        'reason', '卡类型与课程类型不匹配',
        'card_id', p_card_id,
        'member_id', v_member_id,
        'card_type', v_card.card_type,
        'card_category', v_card.card_category,
        'class_type', p_class_type,
        'is_private', v_is_private
      )
    );
    
    RETURN FALSE;
  END IF;
END;
$$;

COMMENT ON FUNCTION deduct_membership_sessions IS '扣除会员卡课时，根据课程类型扣除相应的课时，返回是否成功扣除。支持is_private参数指定是否为私教课';

-- 优化签到处理函数
CREATE OR REPLACE FUNCTION handle_check_in(
  p_member_id uuid, 
  p_name text, 
  p_email text, 
  p_card_id uuid, 
  p_class_type text, 
  p_check_in_date date, 
  p_time_slot text,
  p_trainer_id uuid DEFAULT NULL,
  p_is_1v2 boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_result jsonb;
  v_is_extra boolean;
  v_check_in_id uuid;
  v_class_type class_type;
  v_card_validity jsonb;
  v_is_new_member boolean := false;
  v_is_private boolean;
BEGIN
  -- 转换class_type
  BEGIN
    v_class_type := p_class_type::class_type;
    v_is_private := (v_class_type = 'private');
  EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', '无效的课程类型: ' || p_class_type,
      'error', SQLERRM
    );
  END;

  -- 验证时间段
  IF p_time_slot IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', '请选择有效的时间段',
      'error', 'time_slot_required'
    );
  END IF;

  -- 开始事务
  BEGIN
    -- 检查会员是否存在，不存在则创建
    IF NOT EXISTS (SELECT 1 FROM members WHERE id = p_member_id) THEN
      INSERT INTO members(id, name, email, is_new_member)
      VALUES (p_member_id, p_name, p_email, true);
      
      v_is_extra := true;
      v_is_new_member := true;
      
      PERFORM log_debug(
        'handle_check_in', 
        '创建新会员',
        jsonb_build_object(
          'member_id', p_member_id,
          'name', p_name,
          'email', p_email
        )
      );
    END IF;

    -- 检查是否重复签到（考虑时间段）
    IF check_duplicate_check_in(p_member_id, p_check_in_date, p_class_type, p_time_slot) THEN
      RETURN jsonb_build_object(
        'success', false,
        'message', '今天已经在这个时段签到过了',
        'isDuplicate', true
      );
    END IF;

    -- 验证会员卡
    IF p_card_id IS NOT NULL THEN
      v_card_validity := check_card_validity(p_card_id, p_member_id, p_class_type, p_check_in_date);
      
      IF (v_card_validity->>'is_valid')::boolean THEN
        v_is_extra := false;
      ELSE
        v_is_extra := true;
        
        PERFORM log_debug(
          'handle_check_in', 
          '会员卡验证失败',
          jsonb_build_object(
            'reason', v_card_validity->>'reason',
            'details', v_card_validity->'details'
          ),
          p_member_id
        );
      END IF;
    ELSE
      v_is_extra := true;
      
      PERFORM log_debug(
        'handle_check_in', 
        '未指定会员卡',
        jsonb_build_object(
          'member_id', p_member_id,
          'class_type', p_class_type
        ),
        p_member_id
      );
    END IF;

    -- 插入签到记录
    INSERT INTO check_ins(
      member_id,
      card_id,
      class_type,
      check_in_date,
      trainer_id,
      is_1v2,
      is_extra,
      time_slot,
      is_private
    )
    VALUES (
      p_member_id,
      p_card_id,
      v_class_type,
      p_check_in_date,
      CASE WHEN v_is_private THEN p_trainer_id ELSE NULL END,
      CASE WHEN v_is_private THEN p_is_1v2 ELSE FALSE END,
      v_is_extra,
      p_time_slot,
      v_is_private
    )
    RETURNING id INTO v_check_in_id;

    -- 更新会员信息
    UPDATE members
    SET
      extra_check_ins = CASE WHEN v_is_extra THEN extra_check_ins + 1 ELSE extra_check_ins END,
      last_check_in_date = p_check_in_date
    WHERE id = p_member_id;

    -- 如果是正常签到（非额外签到），扣除课时
    IF NOT v_is_extra AND p_card_id IS NOT NULL THEN
      PERFORM deduct_membership_sessions(p_card_id, p_class_type, v_is_private);
    END IF;

    -- 构建返回结果
    v_result := jsonb_build_object(
      'success', true,
      'message', CASE
        WHEN v_is_new_member THEN '欢迎新会员！已记录签到'
        WHEN v_is_extra AND v_class_type IN ('morning', 'evening') THEN '您暂无有效的团课卡，已记录为额外签到'
        WHEN v_is_extra AND v_class_type = 'private' THEN '您暂无有效的私教卡，已记录为额外签到'
        ELSE '签到成功'
      END,
      'isExtra', v_is_extra,
      'isNewMember', v_is_new_member,
      'checkInId', v_check_in_id
    );

    PERFORM log_debug(
      'handle_check_in', 
      '签到成功',
      jsonb_build_object(
        'check_in_id', v_check_in_id,
        'is_extra', v_is_extra,
        'is_new_member', v_is_new_member,
        'class_type', p_class_type,
        'time_slot', p_time_slot
      ),
      p_member_id
    );

    RETURN v_result;
  EXCEPTION WHEN OTHERS THEN
    -- 记录错误
    PERFORM log_debug(
      'handle_check_in', 
      '签到失败',
      jsonb_build_object(
        'error', SQLERRM,
        'member_id', p_member_id,
        'class_type', p_class_type,
        'time_slot', p_time_slot
      ),
      p_member_id
    );

    -- 返回错误信息
    RETURN jsonb_build_object(
      'success', false,
      'message', SQLERRM
    );
  END;
END;
$$;

COMMENT ON FUNCTION handle_check_in IS '处理会员签到，包括验证会员卡、记录签到、扣除课时等操作'; 