-- 修改handle_check_in函数，修复1v2签到问题
BEGIN;

-- 修改handle_check_in函数，使用更新的check_duplicate_check_in函数
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
SECURITY DEFINER
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
    END IF;

    -- 检查是否重复签到（考虑is_1v2和trainer_id）
    IF check_duplicate_check_in(p_member_id, p_check_in_date, p_class_type, p_time_slot, 
                               CASE WHEN v_is_private THEN p_is_1v2 ELSE false END,
                               CASE WHEN v_is_private THEN p_trainer_id ELSE NULL END) THEN
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
      END IF;
    ELSE
      v_is_extra := true;
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
      PERFORM deduct_membership_sessions(p_card_id, p_class_type, v_is_private, 
                                        CASE WHEN v_is_private THEN p_is_1v2 ELSE FALSE END);
    END IF;

    -- 构建返回结果
    v_result := jsonb_build_object(
      'success', true,
      'message', CASE
        WHEN v_is_new_member THEN '欢迎新会员！已记录签到'
        WHEN v_is_extra THEN CASE
          WHEN v_class_type IN ('morning', 'evening') THEN '您暂无有效的团课卡，已记录为额外签到'
          WHEN v_class_type = 'private' THEN '您暂无有效的私教卡，已记录为额外签到'
          ELSE '签到成功'
        END
        ELSE '签到成功'
      END,
      'isExtra', v_is_extra,
      'isNewMember', v_is_new_member,
      'checkInId', v_check_in_id
    );

    RETURN v_result;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE;
  END;
END;
$$;

COMMIT; 