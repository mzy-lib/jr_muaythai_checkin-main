-- 创建更新会员状态的触发器函数
CREATE OR REPLACE FUNCTION update_member_status()
RETURNS TRIGGER AS $$
BEGIN
  -- 如果是新会员，更新为老会员
  IF (SELECT is_new_member FROM members WHERE id = NEW.member_id) THEN
    UPDATE members
    SET is_new_member = false
    WHERE id = NEW.member_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 创建触发器
DROP TRIGGER IF EXISTS update_member_status_trigger ON check_ins;
CREATE TRIGGER update_member_status_trigger
AFTER INSERT ON check_ins
FOR EACH ROW
EXECUTE FUNCTION update_member_status();

-- 授予权限
GRANT EXECUTE ON FUNCTION update_member_status() TO anon, authenticated, service_role; 