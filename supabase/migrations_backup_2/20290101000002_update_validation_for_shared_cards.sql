-- 修改validate_check_in函数，允许同一会员卡在同一天同类型课程重复签到
-- 这样支持多人共用同一张会员卡的场景，每次签到都会扣除课时
CREATE OR REPLACE FUNCTION validate_check_in(
  p_member_id UUID,
  p_card_id UUID,
  p_class_type TEXT,
  p_check_in_date DATE,
  p_time_slot TEXT,
  p_allow_duplicate BOOLEAN DEFAULT TRUE -- 新增参数，默认允许重复签到
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_extra BOOLEAN := FALSE;
  v_card_valid BOOLEAN := FALSE;
  v_card_type TEXT;
  v_card_category TEXT;
  v_card_subtype TEXT;
  v_remaining_sessions INT;
  v_valid_until DATE;
  v_duplicate_check_in BOOLEAN := FALSE;
  v_reason TEXT := NULL;
  v_check_ins_count INT;
BEGIN
  -- 检查会员是否存在
  IF NOT EXISTS (SELECT 1 FROM members WHERE id = p_member_id) THEN
    RAISE EXCEPTION '会员不存在';
  END IF;
  
  -- 检查是否重复签到（如果不允许重复签到）
  IF NOT p_allow_duplicate THEN
    SELECT COUNT(*) INTO v_check_ins_count
    FROM check_ins
    WHERE member_id = p_member_id
      AND class_type = p_class_type
      AND check_in_date = p_check_in_date
      AND (p_time_slot IS NULL OR time_slot = p_time_slot);
    
    IF v_check_ins_count > 0 THEN
      v_duplicate_check_in := TRUE;
      RETURN jsonb_build_object(
        'is_valid', FALSE,
        'is_extra', FALSE,
        'is_duplicate', TRUE,
        'message', '今天已经在这个时段签到过了'
      );
    END IF;
  END IF;
  
  -- 如果未提供会员卡ID，标记为额外签到
  IF p_card_id IS NULL THEN
    v_is_extra := TRUE;
    v_reason := '未指定会员卡';
    
    RETURN jsonb_build_object(
      'is_valid', TRUE,
      'is_extra', TRUE,
      'card_id', NULL,
      'reason', v_reason
    );
  END IF;
  
  -- 验证会员卡
  SELECT 
    card_type,
    card_category,
    card_subtype,
    CASE 
      WHEN card_type = 'group' THEN remaining_group_sessions
      WHEN card_type = 'private' THEN remaining_private_sessions
      ELSE 0
    END,
    valid_until
  INTO 
    v_card_type,
    v_card_category,
    v_card_subtype,
    v_remaining_sessions,
    v_valid_until
  FROM membership_cards
  WHERE id = p_card_id AND member_id = p_member_id;
  
  -- 检查会员卡是否存在且属于该会员
  IF v_card_type IS NULL THEN
    v_is_extra := TRUE;
    v_reason := '指定的会员卡不存在或不属于该会员';
    
    RETURN jsonb_build_object(
      'is_valid', TRUE,
      'is_extra', TRUE,
      'card_id', NULL,
      'reason', v_reason
    );
  END IF;
  
  -- 检查会员卡是否过期
  IF v_valid_until < CURRENT_DATE THEN
    v_is_extra := TRUE;
    v_reason := '会员卡已过期';
    
    RETURN jsonb_build_object(
      'is_valid', TRUE,
      'is_extra', TRUE,
      'card_id', NULL,
      'reason', v_reason
    );
  END IF;
  
  -- 检查课程类型与会员卡类型是否匹配
  IF (p_class_type IN ('morning', 'evening') AND v_card_type != 'group') OR 
     (p_class_type = 'private' AND v_card_type != 'private') THEN
    v_is_extra := TRUE;
    v_reason := '会员卡类型与课程类型不匹配';
    
    RETURN jsonb_build_object(
      'is_valid', TRUE,
      'is_extra', TRUE,
      'card_id', NULL,
      'reason', v_reason
    );
  END IF;
  
  -- 对于团课课时卡，检查剩余课时
  IF v_card_type = 'group' AND v_card_category = 'session' AND v_remaining_sessions <= 0 THEN
    v_is_extra := TRUE;
    v_reason := '团课次数已用完';
    
    RETURN jsonb_build_object(
      'is_valid', TRUE,
      'is_extra', TRUE,
      'card_id', NULL,
      'reason', v_reason
    );
  END IF;
  
  -- 对于私教课，检查剩余课时
  IF v_card_type = 'private' AND v_remaining_sessions <= 0 THEN
    v_is_extra := TRUE;
    v_reason := '私教课次数已用完';
    
    RETURN jsonb_build_object(
      'is_valid', TRUE,
      'is_extra', TRUE,
      'card_id', NULL,
      'reason', v_reason
    );
  END IF;
  
  -- 对于月卡，检查每日签到次数限制
  IF v_card_type = 'group' AND v_card_category = 'monthly' THEN
    -- 在此处不检查重复签到，允许同一张月卡在同一天被多次使用
    -- 支持多人共用同一张月卡的场景
    NULL;
  END IF;
  
  -- 如果所有检查都通过，会员卡有效
  RETURN jsonb_build_object(
    'is_valid', TRUE,
    'is_extra', FALSE,
    'card_id', p_card_id
  );
END;
$$;

-- 修改handle_check_in函数，添加allow_duplicate参数
CREATE OR REPLACE FUNCTION handle_check_in(
  p_member_id UUID,
  p_name TEXT,
  p_email TEXT,
  p_card_id UUID,
  p_class_type TEXT,
  p_check_in_date DATE,
  p_time_slot TEXT,
  p_trainer_id UUID DEFAULT NULL,
  p_is_1v2 BOOLEAN DEFAULT FALSE,
  p_allow_duplicate BOOLEAN DEFAULT TRUE -- 新增参数，默认允许重复签到
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_check_in_id UUID;
  v_card_id UUID;
  v_is_extra BOOLEAN;
  v_card_check jsonb;
  v_remaining_field TEXT;
  v_new_remaining INT;
BEGIN
  -- 验证会员卡
  v_card_check := validate_check_in(
    p_member_id, 
    p_card_id, 
    p_class_type, 
    p_check_in_date, 
    p_time_slot,
    p_allow_duplicate -- 传递重复签到设置
  );
  
  -- 如果签到无效（例如检测到不允许的重复签到）
  IF NOT (v_card_check->>'is_valid')::BOOLEAN THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'message', v_card_check->>'message'
    ) || v_card_check;
  END IF;
  
  -- 获取额外签到状态和卡ID
  v_is_extra := (v_card_check->>'is_extra')::BOOLEAN;
  v_card_id := CASE 
    WHEN v_is_extra THEN NULL 
    ELSE (v_card_check->>'card_id')::UUID 
  END;
  
  -- 创建签到记录
  INSERT INTO check_ins (
    member_id,
    card_id,
    class_type,
    check_in_date,
    time_slot,
    trainer_id,
    is_1v2,
    is_extra,
    reason
  ) VALUES (
    p_member_id,
    v_card_id,
    p_class_type,
    p_check_in_date,
    p_time_slot,
    p_trainer_id,
    p_is_1v2,
    v_is_extra,
    v_card_check->>'reason'
  ) RETURNING id INTO v_check_in_id;
  
  -- 如果不是额外签到，减少会员卡剩余次数
  IF NOT v_is_extra AND v_card_id IS NOT NULL THEN
    -- 确定要更新的字段
    IF p_class_type IN ('morning', 'evening') THEN
      v_remaining_field := 'remaining_group_sessions';
    ELSE
      v_remaining_field := 'remaining_private_sessions';
    END IF;
    
    -- 获取当前剩余次数并减1
    EXECUTE format('
      UPDATE membership_cards 
      SET %I = GREATEST(%I - 1, 0)
      WHERE id = $1
      RETURNING %I', 
      v_remaining_field, v_remaining_field, v_remaining_field
    ) USING v_card_id INTO v_new_remaining;
  END IF;
  
  -- 更新会员信息（最后签到日期等）
  UPDATE members
  SET last_check_in = CURRENT_TIMESTAMP
  WHERE id = p_member_id;
  
  -- 返回结果
  RETURN jsonb_build_object(
    'success', TRUE,
    'checkInId', v_check_in_id,
    'isExtra', v_is_extra,
    'message', CASE 
      WHEN v_is_extra THEN '签到成功（额外签到）' 
      ELSE '签到成功' 
    END,
    'remainingSessions', v_new_remaining
  );
END;
$$;

-- 设置函数权限
GRANT EXECUTE ON FUNCTION validate_check_in(UUID, UUID, TEXT, DATE, TEXT, BOOLEAN) TO postgres, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION handle_check_in(UUID, TEXT, TEXT, UUID, TEXT, DATE, TEXT, UUID, BOOLEAN, BOOLEAN) TO postgres, anon, authenticated, service_role; 