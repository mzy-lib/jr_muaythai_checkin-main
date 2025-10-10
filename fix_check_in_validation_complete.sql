-- 创建一个新的函数，将check_duplicate_check_in函数的结果转换为布尔值
CREATE OR REPLACE FUNCTION check_duplicate_check_in_bool(
  p_member_id uuid, 
  p_date date, 
  p_class_type text, 
  p_time_slot text DEFAULT NULL::text
) RETURNS boolean AS $$
DECLARE
  v_result jsonb;
BEGIN
  v_result := check_duplicate_check_in(p_member_id, p_date, p_class_type, p_time_slot);
  RETURN (v_result->>'has_duplicate')::boolean;
END;
$$ LANGUAGE plpgsql;

-- 修改validate_check_in函数，使用新的check_duplicate_check_in_bool函数
CREATE OR REPLACE FUNCTION validate_check_in() RETURNS trigger AS $$
DECLARE
  v_member RECORD;
  v_card RECORD;
  v_daily_check_ins integer;
  v_has_same_class_check_in boolean;
  v_is_private boolean;
BEGIN
  -- 设置是否为私教课
  v_is_private := (NEW.class_type = 'private');
  
  -- 记录开始验证
  PERFORM log_debug(
    'validate_check_in',
    '开始验证',
    jsonb_build_object(
      'member_id', NEW.member_id,
      'class_type', NEW.class_type,
      'check_in_date', NEW.check_in_date,
      'time_slot', NEW.time_slot,
      'is_private', v_is_private
    )
  );
  
  -- 检查是否重复签到，使用新的布尔值函数
  IF check_duplicate_check_in_bool(NEW.member_id, NEW.check_in_date, NEW.class_type::TEXT, NEW.time_slot) THEN
    PERFORM log_debug(
      'validate_check_in',
      '重复签到',
      jsonb_build_object(
        'member_id', NEW.member_id,
        'class_type', NEW.class_type,
        'check_in_date', NEW.check_in_date,
        'time_slot', NEW.time_slot
      )
    );
    RAISE EXCEPTION '今天已经在这个时段签到过了';
  END IF;
  
  -- 返回NEW，允许插入/更新操作继续
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 删除不再使用的备份函数
DROP FUNCTION IF EXISTS validate_check_in_backup();
DROP FUNCTION IF EXISTS process_check_in_backup();

-- 删除测试函数
DROP FUNCTION IF EXISTS test_validate_check_in_trigger(); 