-- 向上迁移 (应用更改)
-- 修复扣除课时的函数和触发器

-- 修复deduct_membership_sessions函数
CREATE OR REPLACE FUNCTION deduct_membership_sessions(p_card_id UUID, p_class_type TEXT) 
RETURNS VOID AS $$
DECLARE
  v_card RECORD;
  v_card_type TEXT;
BEGIN
  -- 锁定会员卡记录
  SELECT * INTO v_card 
  FROM membership_cards 
  WHERE id = p_card_id 
  FOR UPDATE;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION '会员卡不存在';
  END IF;
  
  -- 根据课程类型扣除课时
  IF p_class_type IN ('morning', 'evening') AND v_card.card_type = '团课' AND v_card.card_category = '课时卡' THEN
    UPDATE membership_cards 
    SET remaining_group_sessions = remaining_group_sessions - 1 
    WHERE id = p_card_id;
  ELSIF p_class_type = 'private' AND v_card.card_type = '私教' THEN
    UPDATE membership_cards 
    SET remaining_private_sessions = remaining_private_sessions - 1 
    WHERE id = p_card_id;
  END IF;
  
  -- 记录日志
  IF current_setting('app.environment', true) = 'development' THEN
    INSERT INTO debug_logs (function_name, message, details)
    VALUES ('deduct_membership_sessions', '扣除课时', 
      jsonb_build_object(
        'card_id', p_card_id,
        'class_type', p_class_type,
        'card_type', v_card.card_type,
        'card_category', v_card.card_category
      )
    );
  END IF;
END;
$$ LANGUAGE plpgsql;

-- 修复触发器函数
CREATE OR REPLACE FUNCTION trigger_deduct_sessions() 
RETURNS TRIGGER AS $$
BEGIN
  -- 只有非额外签到才扣除课时
  IF NOT NEW.is_extra AND NEW.card_id IS NOT NULL THEN
    -- 显式转换class_type为TEXT
    PERFORM deduct_membership_sessions(NEW.card_id, NEW.class_type::TEXT);
  END IF;
  
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 向下迁移 (回滚更改)
-- 这里不提供回滚脚本，因为回滚会导致函数与表结构不匹配 