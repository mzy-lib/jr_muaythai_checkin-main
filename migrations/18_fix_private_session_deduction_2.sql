-- 向上迁移 (应用更改)
-- 修复私教课扣减课时的问题（第二次修复）

-- 修复deduct_membership_sessions函数
CREATE OR REPLACE FUNCTION deduct_membership_sessions(
  p_card_id UUID,
  p_class_type TEXT,
  p_is_private BOOLEAN DEFAULT FALSE,
  p_is_1v2 BOOLEAN DEFAULT FALSE
)
RETURNS VOID AS $$
DECLARE
  v_card RECORD;
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

  -- 记录开始扣除课时
  PERFORM log_debug(
    'deduct_membership_sessions',
    '开始扣除课时',
    jsonb_build_object(
      'card_id', p_card_id,
      'class_type', p_class_type,
      'is_private', p_is_private,
      'is_1v2', p_is_1v2,
      'card_type', v_card.card_type,
      'card_category', v_card.card_category,
      'remaining_private_sessions', v_card.remaining_private_sessions,
      'remaining_group_sessions', v_card.remaining_group_sessions
    )
  );
  
  -- 根据课程类型扣除课时
  IF NOT p_is_private AND p_class_type IN ('morning', 'evening') AND v_card.card_type = '团课' AND v_card.card_category = '课时卡' THEN
    -- 团课扣除1次课时
    v_deduct_sessions := 1;
    
    -- 检查剩余课时是否足够
    IF v_card.remaining_group_sessions < v_deduct_sessions THEN
      RAISE EXCEPTION '团课课时不足';
    END IF;
    
    UPDATE membership_cards 
    SET remaining_group_sessions = remaining_group_sessions - v_deduct_sessions
    WHERE id = p_card_id;
    
  ELSIF p_is_private AND v_card.card_type = '私教课' THEN
    -- 私教课根据1对1或1对2扣除课时
    v_deduct_sessions := CASE WHEN p_is_1v2 THEN 2 ELSE 1 END;
    
    -- 检查剩余课时是否足够
    IF v_card.remaining_private_sessions < v_deduct_sessions THEN
      RAISE EXCEPTION '私教课时不足';
    END IF;
    
    UPDATE membership_cards 
    SET remaining_private_sessions = remaining_private_sessions - v_deduct_sessions
    WHERE id = p_card_id;
  END IF;
  
  -- 记录扣除课时完成
  PERFORM log_debug(
    'deduct_membership_sessions',
    '扣除课时完成',
    jsonb_build_object(
      'card_id', p_card_id,
      'deducted_sessions', v_deduct_sessions,
      'remaining_private_sessions', CASE 
        WHEN p_is_private THEN v_card.remaining_private_sessions - v_deduct_sessions
        ELSE v_card.remaining_private_sessions
      END,
      'remaining_group_sessions', CASE
        WHEN NOT p_is_private THEN v_card.remaining_group_sessions - v_deduct_sessions
        ELSE v_card.remaining_group_sessions
      END
    )
  );
END;
$$ LANGUAGE plpgsql;

-- 修复触发器函数
CREATE OR REPLACE FUNCTION trigger_deduct_sessions() 
RETURNS TRIGGER AS $$
BEGIN
  -- 只有非额外签到才扣除课时
  IF NOT NEW.is_extra AND NEW.card_id IS NOT NULL THEN
    -- 传递is_private和is_1v2参数
    PERFORM deduct_membership_sessions(NEW.card_id, NEW.class_type::TEXT, NEW.is_private, NEW.is_1v2);
  END IF;
  
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 向下迁移 (回滚更改)
-- 这里不提供回滚脚本，因为这是bug修复 