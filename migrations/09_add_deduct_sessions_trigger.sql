-- 向上迁移 (应用更改)
-- 创建扣除课时的触发器

-- 创建触发器函数
CREATE OR REPLACE FUNCTION trigger_deduct_sessions() 
RETURNS TRIGGER AS $$
BEGIN
  -- 只有非额外签到才扣除课时
  IF NOT NEW.is_extra AND NEW.card_id IS NOT NULL THEN
    PERFORM deduct_membership_sessions(NEW.card_id, NEW.class_type::TEXT);
  END IF;
  
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 创建触发器
CREATE TRIGGER deduct_sessions_trigger
AFTER INSERT ON check_ins
FOR EACH ROW
EXECUTE FUNCTION trigger_deduct_sessions();

-- 向下迁移 (回滚更改)
-- DROP TRIGGER IF EXISTS deduct_sessions_trigger ON check_ins;
-- DROP FUNCTION IF EXISTS trigger_deduct_sessions(); 