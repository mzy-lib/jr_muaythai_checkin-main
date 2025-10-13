-- 删除所有旧版本的check_card_validity函数
DROP FUNCTION IF EXISTS check_card_validity(uuid);
DROP FUNCTION IF EXISTS check_card_validity(uuid, date);
DROP FUNCTION IF EXISTS check_card_validity(uuid, text, boolean, boolean);
DROP FUNCTION IF EXISTS check_card_validity(uuid, uuid, text);
DROP FUNCTION IF EXISTS check_card_validity(uuid, uuid, text, date);

-- 删除所有旧版本的handle_check_in函数
DROP FUNCTION IF EXISTS handle_check_in(uuid, text, text, text, date, uuid, uuid, boolean);
DROP FUNCTION IF EXISTS handle_check_in(uuid, text, text, uuid, text, date, uuid, boolean);
DROP FUNCTION IF EXISTS handle_check_in(uuid, text, text, uuid, text, date, text, uuid, boolean);

-- 重新创建最新版本的check_card_validity函数
CREATE OR REPLACE FUNCTION check_card_validity(
  p_card_id uuid,
  p_member_id uuid,
  p_class_type text,
  p_check_in_date date,
  p_trainer_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_card RECORD;
  v_class_type class_type;
  v_is_private boolean;
  v_result jsonb;
  v_trainer_type text;
BEGIN
  -- 记录开始验证
  PERFORM log_debug(
    'check_card_validity',
    '开始验证会员卡',
    jsonb_build_object(
      'card_id', p_card_id,
      'member_id', p_member_id,
      'class_type', p_class_type,
      'check_in_date', p_check_in_date,
      'trainer_id', p_trainer_id
    )
  );

  -- 转换课程类型
  BEGIN
    v_class_type := p_class_type::class_type;
    v_is_private := (v_class_type = 'private');
  EXCEPTION WHEN OTHERS THEN
    PERFORM log_debug(
      'check_card_validity',
      '无效的课程类型',
      jsonb_build_object(
        'class_type', p_class_type,
        'error', SQLERRM
      )
    );
    RETURN jsonb_build_object(
      'is_valid', false,
      'reason', '无效的课程类型',
      'details', jsonb_build_object(
        'class_type', p_class_type,
        'error', SQLERRM
      )
    );
  END;

  -- 获取会员卡信息
  SELECT *
  INTO v_card
  FROM membership_cards
  WHERE id = p_card_id
  FOR UPDATE;

  -- 检查会员卡是否存在
  IF NOT FOUND THEN
    PERFORM log_debug(
      'check_card_validity',
      '会员卡不存在',
      jsonb_build_object(
        'card_id', p_card_id
      )
    );
    RETURN jsonb_build_object(
      'is_valid', false,
      'reason', '会员卡不存在'
    );
  END IF;

  -- 检查会员卡是否属于该会员
  IF v_card.member_id != p_member_id THEN
    PERFORM log_debug(
      'check_card_validity',
      '会员卡不属于该会员',
      jsonb_build_object(
        'card_id', p_card_id,
        'card_member_id', v_card.member_id,
        'member_id', p_member_id
      )
    );
    RETURN jsonb_build_object(
      'is_valid', false,
      'reason', '会员卡不属于该会员'
    );
  END IF;

  -- 检查会员卡是否过期
  IF v_card.valid_until IS NOT NULL AND v_card.valid_until < p_check_in_date THEN
    PERFORM log_debug(
      'check_card_validity',
      '会员卡已过期',
      jsonb_build_object(
        'card_id', p_card_id,
        'valid_until', v_card.valid_until,
        'check_in_date', p_check_in_date
      )
    );
    RETURN jsonb_build_object(
      'is_valid', false,
      'reason', '会员卡已过期',
      'details', jsonb_build_object(
        'valid_until', v_card.valid_until,
        'check_in_date', p_check_in_date
      )
    );
  END IF;

  -- 检查卡类型是否匹配课程类型
  IF (v_card.card_type = 'group' AND v_is_private) OR
     (v_card.card_type = 'private' AND NOT v_is_private) THEN
    PERFORM log_debug(
      'check_card_validity',
      '卡类型不匹配课程类型',
      jsonb_build_object(
        'card_type', v_card.card_type,
        'class_type', v_class_type,
        'is_private', v_is_private
      )
    );
    RETURN jsonb_build_object(
      'is_valid', false,
      'reason', '卡类型不匹配课程类型',
      'details', jsonb_build_object(
        'card_type', v_card.card_type,
        'class_type', v_class_type
      )
    );
  END IF;

  -- 检查课时是否足够
  IF v_card.card_type = 'group' AND v_card.card_category = 'session' AND
     (v_card.remaining_group_sessions IS NULL OR v_card.remaining_group_sessions <= 0) THEN
    PERFORM log_debug(
      'check_card_validity',
      '团课课时不足',
      jsonb_build_object(
        'card_id', p_card_id,
        'remaining_sessions', v_card.remaining_group_sessions
      )
    );
    RETURN jsonb_build_object(
      'is_valid', false,
      'reason', '团课课时不足',
      'details', jsonb_build_object(
        'remaining_sessions', v_card.remaining_group_sessions
      )
    );
  END IF;

  IF v_card.card_type = 'private' AND
     (v_card.remaining_private_sessions IS NULL OR v_card.remaining_private_sessions <= 0) THEN
    PERFORM log_debug(
      'check_card_validity',
      '私教课时不足',
      jsonb_build_object(
        'card_id', p_card_id,
        'remaining_sessions', v_card.remaining_private_sessions
      )
    );
    RETURN jsonb_build_object(
      'is_valid', false,
      'reason', '私教课时不足',
      'details', jsonb_build_object(
        'remaining_sessions', v_card.remaining_private_sessions
      )
    );
  END IF;

  -- 如果是私教课,检查教练
  IF v_is_private AND p_trainer_id IS NOT NULL THEN
    -- 获取教练类型
    SELECT type INTO v_trainer_type
    FROM trainers
    WHERE id = p_trainer_id;

    IF NOT FOUND THEN
      PERFORM log_debug(
        'check_card_validity',
        '教练不存在',
        jsonb_build_object(
          'trainer_id', p_trainer_id
        )
      );
      RETURN jsonb_build_object(
        'is_valid', false,
        'reason', '教练不存在'
      );
    END IF;

    -- 检查教练类型是否匹配
    IF v_trainer_type != v_card.trainer_type THEN
      PERFORM log_debug(
        'check_card_validity',
        '教练类型不匹配',
        jsonb_build_object(
          'card_trainer_type', v_card.trainer_type,
          'trainer_type', v_trainer_type
        )
      );
      RETURN jsonb_build_object(
        'is_valid', false,
        'reason', '教练类型不匹配',
        'details', jsonb_build_object(
          'card_trainer_type', v_card.trainer_type,
          'trainer_type', v_trainer_type
        )
      );
    END IF;
  END IF;

  -- 记录验证通过
  PERFORM log_debug(
    'check_card_validity',
    '会员卡验证通过',
    jsonb_build_object(
      'card_id', p_card_id,
      'card_type', v_card.card_type,
      'valid_until', v_card.valid_until,
      'remaining_group_sessions', v_card.remaining_group_sessions,
      'remaining_private_sessions', v_card.remaining_private_sessions
    )
  );

  -- 返回验证通过结果
  RETURN jsonb_build_object(
    'is_valid', true,
    'card_info', jsonb_build_object(
      'id', v_card.id,
      'member_id', v_card.member_id,
      'card_type', v_card.card_type,
      'valid_until', v_card.valid_until,
      'remaining_group_sessions', v_card.remaining_group_sessions,
      'remaining_private_sessions', v_card.remaining_private_sessions
    )
  );
END;
$$;

-- 重新创建最新版本的handle_check_in函数
CREATE OR REPLACE FUNCTION handle_check_in(
  p_member_id uuid,
  p_name text,
  p_email text,
  p_class_type text,
  p_check_in_date date,
  p_card_id uuid DEFAULT NULL,
  p_trainer_id uuid DEFAULT NULL,
  p_is_1v2 boolean DEFAULT false,
  p_time_slot text DEFAULT NULL
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
  -- 记录开始签到
  PERFORM log_debug(
    'handle_check_in',
    '开始签到流程',
    jsonb_build_object(
      'member_id', p_member_id,
      'name', p_name,
      'email', p_email,
      'class_type', p_class_type,
      'check_in_date', p_check_in_date,
      'card_id', p_card_id,
      'trainer_id', p_trainer_id,
      'is_1v2', p_is_1v2,
      'time_slot', p_time_slot
    )
  );

  -- 转换课程类型
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
    IF NOT check_member_exists(p_member_id) THEN
      INSERT INTO members(id, name, email, is_new_member)
      VALUES (p_member_id, p_name, p_email, true);
      
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
    
    -- 检查是否重复签到
    IF check_duplicate_check_in(p_member_id, p_check_in_date, p_class_type, p_time_slot) THEN
      RETURN jsonb_build_object(
        'success', false,
        'message', '今天已经在这个时段签到过了',
        'isDuplicate', true
      );
    END IF;
    
    -- 验证会员卡
    IF p_card_id IS NOT NULL THEN
      v_card_validity := check_card_validity(p_card_id, p_member_id, p_class_type, p_check_in_date, p_trainer_id);
      
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
          )
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
        )
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
    RETURN jsonb_build_object(
      'success', true,
      'message', CASE 
        WHEN v_is_new_member THEN '新会员签到成功！'
        WHEN v_is_extra THEN '额外签到成功！'
        ELSE '签到成功！'
      END,
      'isExtra', v_is_extra,
      'isNewMember', v_is_new_member,
      'checkInId', v_check_in_id
    );

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
      )
    );
    
    -- 返回错误信息
    RETURN jsonb_build_object(
      'success', false,
      'message', '签到失败: ' || SQLERRM,
      'error', SQLERRM
    );
  END;
END;
$$;

-- 添加函数注释
COMMENT ON FUNCTION check_card_validity(uuid, uuid, text, date, uuid) IS '验证会员卡有效性,包括卡的存在性、归属、有效期、课时等。对于私教课还会验证教练。';
COMMENT ON FUNCTION handle_check_in(uuid, text, text, text, date, uuid, uuid, boolean, text) IS '处理会员签到流程,包括会员验证、重复签到检查、会员卡验证、签到记录创建和会员信息更新。'; 