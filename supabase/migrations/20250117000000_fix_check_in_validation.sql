-- 修复签到验证逻辑，允许会员在同一天同时签到团课和私教课
-- 即使是同一时间段，只要课程类型不同，也允许签到

-- 更新check_in_validation函数
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

-- 添加注释说明修改内容
COMMENT ON FUNCTION public.check_in_validation() IS '检查签到是否有效，包括时间段验证和重复签到检查。
2025-01-17更新：修改重复签到检查逻辑，允许会员在同一天同时签到团课和私教课，即使是同一时间段。'; 