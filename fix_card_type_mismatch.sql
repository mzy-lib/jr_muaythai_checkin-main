-- 修复课时扣除函数中的卡类型匹配问题
CREATE OR REPLACE FUNCTION deduct_membership_sessions(
  p_card_id UUID,
  p_class_type TEXT,
  p_is_private BOOLEAN DEFAULT FALSE
)
RETURNS VOID AS $$
DECLARE
  v_card RECORD;
BEGIN
  -- 锁定会员卡记录
  SELECT * INTO v_card
  FROM membership_cards
  WHERE id = p_card_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION '会员卡不存在';
  END IF;

  -- 记录调试信息
  INSERT INTO debug_logs (function_name, message, details)
  VALUES ('deduct_membership_sessions', '扣除课时开始',
    jsonb_build_object(
      'card_id', p_card_id,
      'class_type', p_class_type,
      'is_private', p_is_private,
      'card_type', v_card.card_type,
      'card_category', v_card.card_category,
      'card_subtype', v_card.card_subtype,
      'remaining_group_sessions', v_card.remaining_group_sessions,
      'remaining_private_sessions', v_card.remaining_private_sessions
    )
  );

  -- 根据课程类型扣除课时
  IF NOT p_is_private AND p_class_type IN ('morning', 'evening') AND 
     (v_card.card_type = 'group' OR v_card.card_type = 'class') AND 
     (v_card.card_category = 'session' OR v_card.card_category = 'group') THEN
    -- 团课课时卡扣除团课课时
    UPDATE membership_cards
    SET remaining_group_sessions = remaining_group_sessions - 1
    WHERE id = p_card_id;
    
    -- 记录扣除结果
    INSERT INTO debug_logs (function_name, message, details)
    VALUES ('deduct_membership_sessions', '团课课时已扣除',
      jsonb_build_object(
        'card_id', p_card_id,
        'remaining_group_sessions', (SELECT remaining_group_sessions FROM membership_cards WHERE id = p_card_id)
      )
    );
  ELSIF p_is_private AND v_card.card_type = 'private' THEN
    -- 私教卡扣除私教课时
    UPDATE membership_cards
    SET remaining_private_sessions = remaining_private_sessions - 1
    WHERE id = p_card_id;
    
    -- 记录扣除结果
    INSERT INTO debug_logs (function_name, message, details)
    VALUES ('deduct_membership_sessions', '私教课时已扣除',
      jsonb_build_object(
        'card_id', p_card_id,
        'remaining_private_sessions', (SELECT remaining_private_sessions FROM membership_cards WHERE id = p_card_id)
      )
    );
  ELSE
    -- 记录未扣除原因
    INSERT INTO debug_logs (function_name, message, details)
    VALUES ('deduct_membership_sessions', '未扣除课时',
      jsonb_build_object(
        'reason', '卡类型或课程类型不匹配',
        'card_id', p_card_id,
        'class_type', p_class_type,
        'is_private', p_is_private,
        'card_type', v_card.card_type,
        'card_category', v_card.card_category
      )
    );
  END IF;
END;
$$ LANGUAGE plpgsql;

-- 授予权限
GRANT EXECUTE ON FUNCTION deduct_membership_sessions(UUID, TEXT, BOOLEAN) TO anon, authenticated, service_role; 