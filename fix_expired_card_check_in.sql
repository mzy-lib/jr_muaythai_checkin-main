-- 修改handle_check_in函数，使其在检测到过期卡时将签到记录为额外签到，而不是拒绝签到
CREATE OR REPLACE FUNCTION public.handle_check_in(
  p_member_id uuid, 
  p_name text, 
  p_email text, 
  p_card_id uuid, 
  p_class_type text, 
  p_check_in_date date, 
  p_time_slot text, 
  p_trainer_id uuid DEFAULT NULL::uuid, 
  p_is_1v2 boolean DEFAULT false
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_result jsonb;
  v_is_extra boolean;
  v_check_in_id uuid;
  v_class_type class_type;
  v_card_validity jsonb;
  v_is_new_member boolean := false;
  v_is_private boolean;
  v_card_expired boolean := false;
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

      -- 检查卡是否过期
      IF (v_card_validity->>'is_valid')::boolean = false AND 
         (v_card_validity->>'reason') = '会员卡已过期' THEN
        -- 卡已过期，但我们允许签到并标记为额外签到
        v_is_extra := true;
        v_card_expired := true;
        
        PERFORM log_debug(
          'handle_check_in',
          '会员卡已过期，记录为额外签到',
          jsonb_build_object(
            'card_id', p_card_id,
            'valid_until', (v_card_validity->'details'->>'valid_until'),
            'check_in_date', p_check_in_date
          ),
          p_member_id
        );
      ELSIF (v_card_validity->>'is_valid')::boolean THEN
        v_is_extra := false;
      ELSE
        -- 其他无效原因（非过期），仍然标记为额外签到
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
        WHEN v_card_expired THEN '您的会员卡已过期，已记录为额外签到'
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
$function$;

-- 修改测试用例7的描述，反映新的预期行为
COMMENT ON FUNCTION handle_check_in(uuid, text, text, uuid, text, date, text, uuid, boolean) IS 
'处理会员签到，支持团课和私教课签到。
如果会员卡过期，会将签到记录为额外签到而不是拒绝。
如果会员卡课时不足，会将签到记录为额外签到。
如果是新会员或没有指定会员卡，会将签到记录为额外签到。'; 