CREATE OR REPLACE FUNCTION public.handle_check_in(p_member_id uuid, p_card_id uuid, p_class_type text, p_check_in_date date, p_trainer_id uuid, p_is_1v2 boolean, p_time_slot text, p_name text, p_email text)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_check_in_id uuid;
  v_is_extra boolean := true;
  v_class_type_enum class_type;
  v_is_private boolean;
  v_message text;
  v_validity jsonb;
  v_matched_card_id uuid := NULL;
BEGIN
  -- 1. Parameter and precondition checks
  BEGIN
    v_class_type_enum := p_class_type::class_type;
    v_is_private := (v_class_type_enum = 'private'::class_type);
  EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', '无效的课程类型: ' || p_class_type, 'error', SQLERRM);
  END;

  IF p_time_slot IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', '请选择有效的时间段', 'error', 'time_slot_required');
  END IF;

  IF check_duplicate_check_in(p_member_id, p_check_in_date, p_class_type, p_time_slot) THEN
    RETURN jsonb_build_object('success', false, 'message', '今天已经在这个时段签到过了', 'isDuplicate', true);
  END IF;

  -- 2. Member check
  IF NOT check_member_exists(p_member_id) THEN
    INSERT INTO members(id, name, email, is_new_member) VALUES (p_member_id, p_name, p_email, true);
  END IF;
  
  -- 3. Core validation logic: Find the card first
  IF v_is_private THEN
    v_matched_card_id := find_matching_card(p_member_id, p_class_type, p_trainer_id);
    -- 关键修复：如果系统找不到匹配的卡，则必须将所有 card_id 设为 NULL，
    -- 以确保这笔记录被正确地、无歧义地当作“额外签到”处理，防止触发器等外部逻辑的干扰。
    IF v_matched_card_id IS NULL THEN
      p_card_id := NULL;
    END IF;
  ELSE
    v_matched_card_id := p_card_id;
  END IF;

  -- 4. Validate the found card (now includes trainer type matching for all classes)
  v_message := '未找到可用的会员卡';

  IF v_matched_card_id IS NOT NULL THEN
    v_validity := check_card_validity(v_matched_card_id, p_member_id, p_check_in_date, p_class_type, p_trainer_id);

    IF (v_validity->>'is_valid')::boolean THEN
      v_is_extra := false;
      v_message := '签到成功';
    ELSE
      v_message := v_validity->>'reason';
      -- 关键修复：如果卡验证失败，必须将 v_matched_card_id 设为 NULL，
      -- 以确保插入 check_ins 表的 card_id 为空，从而正确记录为额外签到。
      v_matched_card_id := NULL;
    END IF;
  END IF;
  
  -- 5. Insert check-in record
  INSERT INTO check_ins(member_id, card_id, class_type, check_in_date, trainer_id, is_1v2, is_extra, time_slot, is_private)
  VALUES (p_member_id, v_matched_card_id, v_class_type_enum, p_check_in_date,
          CASE WHEN v_is_private THEN p_trainer_id ELSE NULL END,
          CASE WHEN v_is_private THEN p_is_1v2 ELSE FALSE END,
          v_is_extra, p_time_slot, v_is_private)
  RETURNING id INTO v_check_in_id;
  
  -- 6. Deduct session ONLY if it was not an extra check-in
  IF NOT v_is_extra THEN
    -- CRITICAL FIX: Pass all required parameters to the deduction function
    PERFORM deduct_membership_sessions(v_matched_card_id, p_class_type, v_is_private, p_is_1v2);
  END IF;
  
  -- 7. Update member info
  UPDATE members SET last_check_in_date = p_check_in_date WHERE id = p_member_id;
  
  -- 8. Build and return the result
  RETURN jsonb_build_object(
    'success', true,
    'message', v_message,
    'isExtra', v_is_extra,
    'checkInId', v_check_in_id
  );

EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM, 'error', SQLERRM);
END;
$$;
