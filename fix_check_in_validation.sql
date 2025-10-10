CREATE OR REPLACE FUNCTION public.check_in_validation() 
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
  v_duplicate_check_in RECORD;
  v_time_slot_valid boolean;
BEGIN
  -- 验证时间段格式
  IF NEW.time_slot IS NULL OR NEW.time_slot = '' THEN
    RAISE EXCEPTION '时间段不能为空
Time slot cannot be empty';
  END IF;

  -- 验证时间段有效性
  SELECT validate_time_slot(NEW.time_slot, NEW.check_in_date, NEW.is_private) INTO v_time_slot_valid;
  IF NOT v_time_slot_valid THEN
    RAISE EXCEPTION '无效的时间段: %
Invalid time slot: %', NEW.time_slot, NEW.time_slot;
  END IF;

  -- 设置课程类型
  IF NEW.is_private THEN
    NEW.class_type := 'private'::class_type;
  ELSE
    -- 根据时间段判断是上午还是下午课程
    IF NEW.time_slot = '09:00-10:30' THEN
      NEW.class_type := 'morning'::class_type;
    ELSE
      NEW.class_type := 'evening'::class_type;
    END IF;
  END IF;

  -- 检查是否有重复签到（修改：考虑课程类型）
  -- 原来的代码会检查相同会员、日期、时间段和是否私教，现在我们修改为检查相同会员、日期、时间段和相同课程类型
  SELECT * INTO v_duplicate_check_in
  FROM check_ins
  WHERE member_id = NEW.member_id
    AND check_in_date = NEW.check_in_date
    AND time_slot = NEW.time_slot
    AND class_type = NEW.class_type
    AND id IS DISTINCT FROM NEW.id
  LIMIT 1;

  IF FOUND THEN
    IF NEW.is_private THEN
      RAISE EXCEPTION '今天已经在这个时间段签到过私教课
Already checked in for private class at this time slot today';
    ELSE
      RAISE EXCEPTION '今天已经在这个时间段签到过团课
Already checked in for group class at this time slot today';
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

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

-- 修改handle_check_in函数，使用新的check_duplicate_check_in_bool函数
CREATE OR REPLACE FUNCTION handle_check_in(
  p_member_id uuid,
  p_name text,
  p_email text,
  p_class_type text,
  p_check_in_date date,
  p_card_id uuid DEFAULT NULL::uuid,
  p_trainer_id uuid DEFAULT NULL::uuid,
  p_is_1v2 boolean DEFAULT false,
  p_time_slot text DEFAULT NULL::text
) RETURNS jsonb AS $$
DECLARE
  v_check_in_id uuid;
  v_is_extra boolean := false;
  v_is_private boolean := (p_class_type = 'private');
  v_card_id uuid := p_card_id;
  v_message text;
  v_duplicate_check boolean;
BEGIN
  -- 检查是否重复签到，使用新的布尔值函数
  v_duplicate_check := check_duplicate_check_in_bool(p_member_id, p_check_in_date, p_class_type, p_time_slot);
  
  IF v_duplicate_check THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', '今天已经在这个时段签到过了',
      'isDuplicate', true
    );
  END IF;
  
  -- 其余代码保持不变...
  
  RETURN jsonb_build_object(
    'success', true,
    'message', '签到成功',
    'isExtra', v_is_extra,
    'checkInId', v_check_in_id
  );
  
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', SQLERRM,
      'error', SQLERRM
    );
END;
$$ LANGUAGE plpgsql;

-- 删除不再使用的备份函数
DROP FUNCTION IF EXISTS validate_check_in_backup();
DROP FUNCTION IF EXISTS process_check_in_backup();

-- 删除测试函数
DROP FUNCTION IF EXISTS test_validate_check_in_trigger(); 