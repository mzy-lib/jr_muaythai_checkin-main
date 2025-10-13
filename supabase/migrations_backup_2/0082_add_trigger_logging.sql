BEGIN;

-- 重新创建 process_check_in 函数，添加执行日志
CREATE OR REPLACE FUNCTION process_check_in()
RETURNS TRIGGER AS $$
BEGIN
  RAISE NOTICE 'process_check_in 开始执行: member_id=%, is_extra=%', NEW.member_id, NEW.is_extra;
  
  -- 更新会员信息
  UPDATE members
  SET 
    remaining_classes = CASE 
      WHEN membership = 'single_class' AND NEW.is_extra = false 
      THEN remaining_classes - 1
      ELSE remaining_classes
    END,
    extra_check_ins = CASE 
      WHEN NEW.is_extra = true 
      THEN extra_check_ins + 1
      ELSE extra_check_ins
    END,
    daily_check_ins = daily_check_ins + 1,
    last_check_in_date = NEW.check_in_date,
    is_new_member = CASE
      WHEN is_new_member AND NEW.is_extra = true THEN false
      ELSE is_new_member
    END
  WHERE id = NEW.member_id;
  
  RAISE NOTICE 'process_check_in 执行完成: affected_rows=%', FOUND;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 重新创建触发器
DROP TRIGGER IF EXISTS process_check_in_trigger ON check_ins;
CREATE TRIGGER process_check_in_trigger
  AFTER INSERT ON check_ins
  FOR EACH ROW
  EXECUTE FUNCTION process_check_in();

COMMIT; 