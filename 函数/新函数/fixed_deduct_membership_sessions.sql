CREATE OR REPLACE FUNCTION public.deduct_membership_sessions(p_card_id uuid, p_class_type text, p_is_private boolean DEFAULT false, p_is_1v2 boolean DEFAULT false)
RETURNS void
LANGUAGE plpgsql
AS $$
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
      'remaining_private_sessions', v_card.remaining_private_sessions,
      'remaining_kids_sessions', v_card.remaining_kids_sessions
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
  IF p_is_private AND (v_card.card_type = 'private' OR v_card.card_type = '私教课') THEN
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

  -- 儿童团课课程
  ELSIF NOT p_is_private AND (p_class_type = 'kids group' OR p_class_type LIKE '%kids%') AND
        (v_card.card_type = '儿童团课' OR v_card.card_type LIKE '%kids%') THEN
    -- 检查剩余儿童团课课时
    IF v_card.remaining_kids_sessions IS NULL OR v_card.remaining_kids_sessions <= 0 THEN
      INSERT INTO debug_logs (function_name, message, details)
      VALUES ('deduct_membership_sessions', '儿童团课课时不足，不扣除',
        jsonb_build_object(
          'card_id', p_card_id,
          'remaining_kids_sessions', v_card.remaining_kids_sessions
        )
      );
      RETURN;
    END IF;

    -- 扣除儿童团课课时
    UPDATE membership_cards
    SET remaining_kids_sessions = remaining_kids_sessions - 1
    WHERE id = p_card_id;

    -- 记录儿童团课课时扣除
    INSERT INTO debug_logs (function_name, message, details)
    VALUES ('deduct_membership_sessions', '儿童团课课时已扣除',
      jsonb_build_object(
        'card_id', p_card_id,
        'remaining_kids_sessions', v_card.remaining_kids_sessions - 1
      )
    );

  -- 团课课程
  ELSIF NOT p_is_private AND p_class_type IN ('morning', 'evening') AND
        (v_card.card_type = 'group' OR v_card.card_type = 'class' OR v_card.card_type = '团课') AND
        (v_card.card_category = 'session' OR v_card.card_category = 'group' OR v_card.card_category = '课时卡') THEN
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
$$;
