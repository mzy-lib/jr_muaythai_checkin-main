CREATE OR REPLACE FUNCTION public.check_card_validity(p_card_id uuid, p_member_id uuid, p_class_type text, p_check_in_date date, p_trainer_id uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_card RECORD;
  v_class_type class_type;
  v_is_private boolean;
  v_is_kids_group boolean;
  v_result jsonb;
  v_trainer_level text;
  v_card_trainer_level text;
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
    v_is_private := (v_class_type = 'private'::class_type);
    v_is_kids_group := (v_class_type = 'kids group'::class_type);
  EXCEPTION WHEN OTHERS THEN
    PERFORM log_debug('check_card_validity', '无效的课程类型', jsonb_build_object('class_type', p_class_type, 'error', SQLERRM));
    RETURN jsonb_build_object('is_valid', false, 'reason', '无效的课程类型');
  END;

  -- 获取会员卡信息
  SELECT * INTO v_card FROM membership_cards WHERE id = p_card_id FOR UPDATE;

  -- 检查会员卡是否存在
  IF NOT FOUND THEN
    PERFORM log_debug('check_card_validity', '会员卡不存在', jsonb_build_object('card_id', p_card_id));
    RETURN jsonb_build_object('is_valid', false, 'reason', '会员卡不存在');
  END IF;

  -- 检查会员卡是否属于该会员
  IF v_card.member_id != p_member_id THEN
    PERFORM log_debug('check_card_validity', '会员卡不属于该会员', jsonb_build_object('card_member_id', v_card.member_id, 'requested_member_id', p_member_id));
    RETURN jsonb_build_object('is_valid', false, 'reason', '会员卡不属于该会员');
  END IF;

  -- 检查会员卡是否过期
  IF v_card.valid_until IS NOT NULL AND v_card.valid_until < p_check_in_date THEN
    PERFORM log_debug('check_card_validity', '会员卡已过期', jsonb_build_object('valid_until', v_card.valid_until, 'check_in_date', p_check_in_date));
    RETURN jsonb_build_object('is_valid', false, 'reason', '会员卡已过期');
  END IF;

  -- 检查卡类型是否匹配课程类型
  IF (v_card.card_type = '私教课' AND NOT v_is_private) OR
     (v_card.card_type = '团课' AND v_is_private) OR
     (v_card.card_type = '儿童团课' AND NOT v_is_kids_group) OR
     (v_card.card_type != '儿童团课' AND v_is_kids_group) THEN
    PERFORM log_debug('check_card_validity', '卡类型不匹配课程类型', jsonb_build_object('card_type', v_card.card_type, 'class_type', p_class_type));
    RETURN jsonb_build_object('is_valid', false, 'reason', '卡类型不匹配课程类型');
  END IF;

  -- 如果是私教课，检查教练等级
  IF v_is_private AND p_trainer_id IS NOT NULL THEN
    -- 获取教练等级
    SELECT notes INTO v_trainer_level FROM trainers WHERE id = p_trainer_id;
    -- 获取卡要求的教练等级
    v_card_trainer_level := v_card.card_subtype;

    -- 如果卡等级是高级，但教练是JR，则视为额外签到
    IF v_card_trainer_level = '高级教练' AND v_trainer_level LIKE 'JR%' THEN
        PERFORM log_debug('check_card_validity', '高阶卡用于低阶教练', jsonb_build_object('card_level', v_card_trainer_level, 'trainer_level', v_trainer_level));
        RETURN jsonb_build_object('is_valid', false, 'reason', '高阶卡用于低阶教练');
    END IF;

    -- 如果卡等级和教练等级不匹配 (例如 JR卡 刷 高级教练)
    IF v_card_trainer_level != v_trainer_level THEN
        PERFORM log_debug('check_card_validity', '卡等级不匹配教练等级', jsonb_build_object('card_level', v_card_trainer_level, 'trainer_level', v_trainer_level));
        RETURN jsonb_build_object('is_valid', false, 'reason', '卡等级不匹配教练等级');
    END IF;
  END IF;

  -- 检查课时是否足够
  IF (v_card.card_type = '私教课' AND (v_card.remaining_private_sessions IS NULL OR v_card.remaining_private_sessions <= 0)) OR
     (v_card.card_type = '团课' AND v_card.card_category = '课时卡' AND (v_card.remaining_group_sessions IS NULL OR v_card.remaining_group_sessions <= 0)) OR
     (v_card.card_type = '儿童团课' AND (v_card.remaining_kids_sessions IS NULL OR v_card.remaining_kids_sessions <= 0)) THEN
    PERFORM log_debug('check_card_validity', '课时不足', jsonb_build_object('card_type', v_card.card_type, 'remaining_private', v_card.remaining_private_sessions, 'remaining_group', v_card.remaining_group_sessions, 'remaining_kids', v_card.remaining_kids_sessions));
    RETURN jsonb_build_object('is_valid', false, 'reason', '课时不足');
  END IF;

  -- 会员卡有效
  RETURN jsonb_build_object('is_valid', true, 'card_info', jsonb_build_object('card_id', v_card.id));
END;
$$;
