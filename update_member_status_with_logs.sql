-- 修改会员状态更新函数以添加日志记录
CREATE OR REPLACE FUNCTION update_member_status()
RETURNS TRIGGER AS $$
BEGIN
  -- 如果是新会员，更新为老会员
  IF (SELECT is_new_member FROM members WHERE id = NEW.member_id) THEN
    UPDATE members
    SET is_new_member = false
    WHERE id = NEW.member_id;
    
    -- 记录日志
    INSERT INTO debug_logs (function_name, message, member_id, details)
    VALUES ('update_member_status', '会员状态已更新', NEW.member_id,
      jsonb_build_object(
        'old_status', 'new',
        'new_status', 'old',
        'check_in_id', NEW.id
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 重新创建触发器
DROP TRIGGER IF EXISTS update_member_status_trigger ON check_ins;
CREATE TRIGGER update_member_status_trigger
AFTER INSERT ON check_ins
FOR EACH ROW
EXECUTE FUNCTION update_member_status();

-- 授予权限
GRANT EXECUTE ON FUNCTION update_member_status() TO anon, authenticated, service_role; 