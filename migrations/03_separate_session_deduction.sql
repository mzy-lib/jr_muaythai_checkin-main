-- 向上迁移 (应用更改)
-- 备份原始函数
CREATE OR REPLACE FUNCTION process_check_in_backup() 
RETURNS trigger AS $$ 
BEGIN 
  -- 复制原始函数的内容
  RETURN NEW; 
END; 
$$ LANGUAGE plpgsql;

-- 创建课时扣除函数
CREATE OR REPLACE FUNCTION deduct_membership_sessions(p_card_id UUID, p_class_type TEXT) 
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
  
  -- 根据课程类型扣除课时
  IF v_card.card_type = 'group' AND v_card.card_category = 'session' THEN
    UPDATE membership_cards 
    SET remaining_group_sessions = remaining_group_sessions - 1 
    WHERE id = p_card_id;
  ELSIF v_card.card_type = 'private' THEN
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

-- 优化处理签到函数
CREATE OR REPLACE FUNCTION process_check_in() 
RETURNS trigger AS $$
DECLARE
  v_member RECORD;
BEGIN
  -- 更新会员信息
  UPDATE members 
  SET 
    extra_check_ins = CASE WHEN NEW.is_extra THEN extra_check_ins + 1 ELSE extra_check_ins END,
    last_check_in_date = NEW.check_in_date 
  WHERE id = NEW.member_id;
  
  -- 扣除课时
  IF NEW.card_id IS NOT NULL AND NOT NEW.is_extra THEN
    PERFORM deduct_membership_sessions(NEW.card_id, NEW.class_type);
  END IF;
  
  -- 记录日志
  IF current_setting('app.environment', true) = 'development' THEN
    INSERT INTO debug_logs (function_name, message, member_id, details)
    VALUES ('process_check_in', '处理完成', NEW.member_id, 
      jsonb_build_object(
        'check_in_date', NEW.check_in_date,
        'class_type', NEW.class_type,
        'is_extra', NEW.is_extra,
        'card_id', NEW.card_id
      )
    );
  END IF;
  
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 向下迁移 (回滚更改)
-- 恢复原始函数
-- CREATE OR REPLACE FUNCTION process_check_in() 
-- RETURNS trigger AS $$ 
-- BEGIN 
--   -- 从备份恢复原始函数内容
--   RETURN NEW; 
-- END; 
-- $$ LANGUAGE plpgsql;
-- 
-- DROP FUNCTION IF EXISTS deduct_membership_sessions(UUID, TEXT);
-- DROP FUNCTION IF EXISTS process_check_in_backup(); 