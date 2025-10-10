BEGIN;

-- 重新创建 process_check_in 函数
CREATE OR REPLACE FUNCTION process_check_in()
RETURNS TRIGGER AS $$
BEGIN
  -- 更新会员信息
  UPDATE members
  SET 
    remaining_classes = CASE 
      WHEN membership = 'single_class' AND remaining_classes > 0 AND NEW.is_extra = false 
      THEN remaining_classes - 1
      ELSE remaining_classes
    END,
    extra_check_ins = CASE 
      WHEN NEW.is_extra = true 
      THEN extra_check_ins + 1
      ELSE extra_check_ins
    END,
    daily_check_ins = daily_check_ins + 1,
    last_check_in_date = NEW.check_in_date
  WHERE id = NEW.member_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMIT; 