CREATE OR REPLACE FUNCTION public.check_card_validity(p_card_id uuid, p_member_id uuid, p_check_in_date date, p_class_type text, p_trainer_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_card RECORD;
  v_class_type_enum class_type;
  v_is_private boolean;
  v_trainer_type text;
  v_card_trainer_type text;
BEGIN
  -- Convert class type
  BEGIN
    v_class_type_enum := p_class_type::class_type;
    v_is_private := (v_class_type_enum = 'private'::class_type);
  EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('is_valid', false, 'reason', '无效的课程类型');
  END;

  -- Get card info
  SELECT * INTO v_card FROM membership_cards WHERE id = p_card_id FOR UPDATE;

  -- Check if card exists
  IF NOT FOUND THEN
    RETURN jsonb_build_object('is_valid', false, 'reason', '会员卡不存在');
  END IF;

  -- Check if card belongs to the member
  IF v_card.member_id != p_member_id THEN
    RETURN jsonb_build_object('is_valid', false, 'reason', '会员卡不属于该会员');
  END IF;

  -- Check card expiration
  IF v_card.valid_until IS NOT NULL AND v_card.valid_until < p_check_in_date THEN
    RETURN jsonb_build_object('is_valid', false, 'reason', '会员卡已过期');
  END IF;

  -- Check if card type matches class type
  IF (v_card.card_type = '私教课' AND NOT v_is_private) OR
     (v_card.card_type = '团课' AND v_is_private) OR
     (v_card.card_type = '儿童团课' AND v_is_private) THEN
    RETURN jsonb_build_object('is_valid', false, 'reason', '卡类型不匹配课程类型');
  END IF;

  -- Perform strict trainer type matching ONLY for private classes
  -- 只对私教课进行教练等级匹配验证，团课和儿童团课不需要
  IF v_is_private AND p_trainer_id IS NOT NULL AND trim(p_trainer_id::text) != '' THEN
    SELECT lower(trim(type)) INTO v_trainer_type FROM trainers WHERE id = p_trainer_id;

    -- CRITICAL FIX: Ensure trainer exists and type is known
    IF v_trainer_type IS NULL THEN
        RETURN jsonb_build_object('is_valid', false, 'reason', '签到教练信息不存在或类型未知');
    END IF;

    v_card_trainer_type := lower(trim(v_card.trainer_type));

    -- Strict check: card's trainer type must match the session's trainer type
    IF v_card_trainer_type != v_trainer_type THEN
        RETURN jsonb_build_object('is_valid', false, 'reason', '卡等级(' || v_card_trainer_type || ')与教练等级(' || v_trainer_type || ')不匹配');
    END IF;
  END IF;

  -- Check for remaining sessions (区分课时卡和月卡)
  IF v_card.card_type = '私教课' THEN
    -- 私教课检查私教课时
    IF v_card.remaining_private_sessions IS NULL OR v_card.remaining_private_sessions <= 0 THEN
      RETURN jsonb_build_object('is_valid', false, 'reason', '课时不足');
    END IF;
  ELSIF v_card.card_type = '团课' THEN
    -- 团课需要区分课时卡和月卡
    IF v_card.card_category IN ('sessions', 'group', '课时卡') THEN
      -- 课时卡检查剩余课时
      IF v_card.remaining_group_sessions IS NULL OR v_card.remaining_group_sessions <= 0 THEN
        RETURN jsonb_build_object('is_valid', false, 'reason', '课时不足');
      END IF;
    ELSIF v_card.card_category IN ('monthly', 'unlimited', '月卡') THEN
      -- 月卡只检查有效期，不检查课时（已在上面检查过有效期）
      -- 月卡无需额外检查
      NULL;
    ELSE
      -- 未知的卡类别，默认检查课时
      IF v_card.remaining_group_sessions IS NULL OR v_card.remaining_group_sessions <= 0 THEN
        RETURN jsonb_build_object('is_valid', false, 'reason', '课时不足');
      END IF;
    END IF;
  ELSIF v_card.card_type = '儿童团课' THEN
    -- 儿童团课检查儿童团课课时
    IF v_card.remaining_kids_sessions IS NULL OR v_card.remaining_kids_sessions <= 0 THEN
      RETURN jsonb_build_object('is_valid', false, 'reason', '课时不足');
    END IF;
  END IF;

  -- All checks passed, card is valid
  RETURN jsonb_build_object('is_valid', true);
END;
$$;
