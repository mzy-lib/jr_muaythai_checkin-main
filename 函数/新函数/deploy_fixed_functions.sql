-- 部署修复后的函数，解决团课签到被判断为额外签到的问题
-- 执行顺序：先部署 find_matching_card，再部署 handle_check_in

-- 1. 修复后的 find_matching_card 函数 - 支持所有课程类型的卡匹配
CREATE OR REPLACE FUNCTION public.find_matching_card(p_member_id uuid, p_class_type text, p_trainer_id uuid)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
    v_card_id uuid;
    v_trainer_type text;
BEGIN
    -- 处理私教课
    IF p_class_type = 'private' THEN
        -- 1. Get the trainer_type from the trainer's profile.
        SELECT type INTO v_trainer_type FROM public.trainers WHERE id = p_trainer_id;

        -- If trainer not found or has no type, we cannot find a matching card.
        IF v_trainer_type IS NULL THEN
            RETURN NULL;
        END IF;

        -- 2. Find a valid private card that matches the member, class type, and trainer type.
        SELECT id INTO v_card_id
        FROM public.membership_cards
        WHERE
            member_id = p_member_id
            AND card_type = '私教课' -- Corresponds to 'private' class type
            AND (
              -- The card's level must be sufficient for the trainer's level.
              -- A 'senior' card can be used for both 'senior' and 'jr' trainers.
              -- A 'jr' card can only be used for 'jr' trainers.
              (lower(trim(trainer_type)) = 'senior') OR
              (lower(trim(trainer_type)) = 'jr' AND lower(trim(v_trainer_type)) = 'jr')
            )
            AND (valid_until IS NULL OR valid_until >= CURRENT_DATE)
            AND remaining_private_sessions > 0
        ORDER BY valid_until ASC NULLS LAST -- Use the card that expires soonest first
        LIMIT 1;

        RETURN v_card_id;
    END IF;

    -- 处理团课 (morning, evening)
    IF p_class_type IN ('morning', 'evening') THEN
        -- 查找适用于团课的卡（课时卡或月卡）
        SELECT id INTO v_card_id
        FROM public.membership_cards
        WHERE
            member_id = p_member_id
            AND (
                -- 课时卡：团课类型且有剩余课时
                (card_type IN ('group', 'class', '团课')
                 AND card_category IN ('sessions', 'group', '课时卡')
                 AND remaining_group_sessions > 0)
                OR
                -- 月卡：团课类型且在有效期内
                (card_type IN ('group', 'class', '团课')
                 AND card_category IN ('monthly', 'unlimited', '月卡')
                 AND (valid_until IS NULL OR valid_until >= CURRENT_DATE))
            )
            AND (valid_until IS NULL OR valid_until >= CURRENT_DATE)
        ORDER BY
            -- 优先使用即将到期的卡
            valid_until ASC NULLS LAST,
            -- 其次优先使用课时卡（避免浪费月卡）
            CASE WHEN card_category IN ('sessions', 'group', '课时卡') THEN 1 ELSE 2 END
        LIMIT 1;

        RETURN v_card_id;
    END IF;

    -- 处理儿童团课
    IF p_class_type = 'kids group' OR p_class_type LIKE '%kids%' THEN
        -- 查找适用于儿童团课的卡（使用 remaining_group_sessions 字段）
        SELECT id INTO v_card_id
        FROM public.membership_cards
        WHERE
            member_id = p_member_id
            AND (card_type = '儿童团课' OR card_type LIKE '%kids%')
            AND remaining_group_sessions > 0
            AND (valid_until IS NULL OR valid_until >= CURRENT_DATE)
        ORDER BY valid_until ASC NULLS LAST
        LIMIT 1;

        RETURN v_card_id;
    END IF;

    -- 未匹配的课程类型
    RETURN NULL;
END;
$$;

-- 2. 修复后的 handle_check_in 函数 - 对所有课程类型都使用 find_matching_card
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
  
  -- 3. Core validation logic: 对所有课程类型都使用 find_matching_card 函数查找匹配的卡
  v_matched_card_id := find_matching_card(p_member_id, p_class_type, p_trainer_id);
  
  -- 如果系统找不到匹配的卡，则必须将所有 card_id 设为 NULL，
  -- 以确保这笔记录被正确地、无歧义地当作"额外签到"处理
  IF v_matched_card_id IS NULL THEN
    p_card_id := NULL;
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
