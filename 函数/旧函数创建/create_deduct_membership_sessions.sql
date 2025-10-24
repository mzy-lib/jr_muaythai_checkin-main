CREATE OR REPLACE FUNCTION public.deduct_membership_sessions(p_card_id uuid, p_class_type text, p_is_private boolean, p_is_1v2 boolean)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_card RECORD;
  v_class_type text;
  v_is_private boolean;
  v_is_kids_group boolean;
  v_deduct_sessions INTEGER;
BEGIN
  -- 锁定会员卡记录
  SELECT * INTO v_card 
  FROM membership_cards 
  WHERE id = p_card_id 
  FOR UPDATE;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION '会员卡不存在';
  END IF;

  -- 使用传入的is_private参数
  v_is_private := COALESCE(p_is_private, false);
  
  -- 判断是否为儿童团课（支持多种格式）
  -- 使用LIKE操作符提高匹配灵活性
  v_is_kids_group := (p_class_type LIKE '%kids%' OR p_class_type LIKE '%儿童%');
  
  -- 记录课程类型
  v_class_type := p_class_type;

  -- 记录开始扣除课时
  PERFORM log_debug(
    'deduct_membership_sessions',
    '开始扣除课时',
    jsonb_build_object(
      'card_id', p_card_id,
      'class_type', p_class_type,
      'is_private', v_is_private,
      'is_kids_group', v_is_kids_group,
      'is_1v2', p_is_1v2,
      'card_type', v_card.card_type,
      'card_category', v_card.card_category,
      'remaining_private_sessions', v_card.remaining_private_sessions,
      'remaining_group_sessions', v_card.remaining_group_sessions,
      'remaining_kids_sessions', v_card.remaining_kids_sessions
    )
  );
  
  -- 私教课
  IF v_is_private AND v_card.card_type = '私教课' THEN
    -- 统一扣除1次课时（1对1和1对2都一样）
    v_deduct_sessions := 1;
    
    -- 检查剩余课时是否足够
    IF v_card.remaining_private_sessions < v_deduct_sessions THEN
      PERFORM log_debug(
        'deduct_membership_sessions',
        '私教课时不足',
        jsonb_build_object(
          'card_id', p_card_id,
          'remaining_private_sessions', v_card.remaining_private_sessions
        )
      );
      RAISE EXCEPTION '私教课时不足';
    END IF;
    
    -- 扣除私教课时
    UPDATE membership_cards 
    SET remaining_private_sessions = remaining_private_sessions - v_deduct_sessions
    WHERE id = p_card_id;
    
    -- 记录扣除课时完成
    PERFORM log_debug(
      'deduct_membership_sessions',
      '私教课时已扣除',
      jsonb_build_object(
        'card_id', p_card_id,
        'remaining_private_sessions', v_card.remaining_private_sessions - v_deduct_sessions
      )
    );
  
  -- 儿童团课 - 优先判断是否是儿童团课，因为它是团课的特殊类型
  ELSIF v_is_kids_group AND (v_card.card_type = '儿童团课' OR v_card.card_type LIKE '%kids%') THEN
    -- 儿童团课扣除1次课时
    v_deduct_sessions := 1;
    
    -- 检查剩余课时是否足够
    IF v_card.remaining_kids_sessions IS NULL OR v_card.remaining_kids_sessions < v_deduct_sessions THEN
      PERFORM log_debug(
        'deduct_membership_sessions',
        '儿童团课课时不足',
        jsonb_build_object(
          'card_id', p_card_id,
          'remaining_kids_sessions', v_card.remaining_kids_sessions
        )
      );
      RAISE EXCEPTION '儿童团课课时不足';
    END IF;
    
    -- 扣除儿童团课课时
    UPDATE membership_cards 
    SET remaining_kids_sessions = remaining_kids_sessions - v_deduct_sessions
    WHERE id = p_card_id;
    
    -- 记录扣除课时完成
    PERFORM log_debug(
      'deduct_membership_sessions',
      '儿童团课课时已扣除',
      jsonb_build_object(
        'card_id', p_card_id,
        'remaining_kids_sessions', v_card.remaining_kids_sessions - v_deduct_sessions
      )
    );
  
  -- 团课
  ELSIF NOT v_is_private AND NOT v_is_kids_group AND v_card.card_type = '团课' AND v_card.card_category = '课时卡' THEN
    -- 团课扣除1次课时
    v_deduct_sessions := 1;
    
    -- 检查剩余课时是否足够
    IF v_card.remaining_group_sessions IS NULL OR v_card.remaining_group_sessions < v_deduct_sessions THEN
      PERFORM log_debug(
        'deduct_membership_sessions',
        '团课课时不足',
        jsonb_build_object(
          'card_id', p_card_id,
          'remaining_group_sessions', v_card.remaining_group_sessions
        )
      );
      RAISE EXCEPTION '团课课时不足';
    END IF;
    
    -- 扣除团课课时
    UPDATE membership_cards 
    SET remaining_group_sessions = remaining_group_sessions - v_deduct_sessions
    WHERE id = p_card_id;
    
    -- 记录扣除课时完成
    PERFORM log_debug(
      'deduct_membership_sessions',
      '团课课时已扣除',
      jsonb_build_object(
        'card_id', p_card_id,
        'remaining_group_sessions', v_card.remaining_group_sessions - v_deduct_sessions
      )
    );
  
  -- 其他情况，记录但不扣除
  ELSE
    PERFORM log_debug(
      'deduct_membership_sessions',
      '未找到匹配的卡类型和课程类型组合，不扣除课时',
      jsonb_build_object(
        'card_id', p_card_id,
        'class_type', p_class_type,
        'is_private', v_is_private,
        'is_kids_group', v_is_kids_group,
        'card_type', v_card.card_type,
        'card_category', v_card.card_category
      )
    );
  END IF;
  
  -- 最终记录
  PERFORM log_debug(
    'deduct_membership_sessions',
    '扣除课时完成',
    jsonb_build_object(
      'card_id', p_card_id,
      'deducted_sessions', v_deduct_sessions,
      'remaining_private_sessions', CASE 
        WHEN v_is_private THEN v_card.remaining_private_sessions - v_deduct_sessions
        ELSE v_card.remaining_private_sessions
      END,
      'remaining_group_sessions', CASE
        WHEN NOT v_is_private AND NOT v_is_kids_group THEN v_card.remaining_group_sessions - v_deduct_sessions
        ELSE v_card.remaining_group_sessions
      END,
      'remaining_kids_sessions', CASE
        WHEN v_is_kids_group THEN v_card.remaining_kids_sessions - v_deduct_sessions
        ELSE v_card.remaining_kids_sessions
      END
    )
  );
END;
$$;
