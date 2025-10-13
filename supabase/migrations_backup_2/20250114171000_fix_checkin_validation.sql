CREATE OR REPLACE FUNCTION validate_check_in()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
  v_member RECORD;
  v_daily_check_ins integer;
  v_has_same_class_check_in boolean;
  v_processed boolean;
BEGIN
  -- Check if this check-in has already been processed
  SELECT EXISTS (
    SELECT 1 
    FROM debug_logs 
    WHERE member_id = NEW.member_id 
      AND created_at >= CURRENT_TIMESTAMP - interval '1 second'
      AND function_name = 'validate_check_in'
  ) INTO v_processed;

  IF v_processed THEN
    -- Skip validation if already processed
    RETURN NEW;
  END IF;

  -- Get member details with lock
  SELECT *
  INTO v_member
  FROM members
  WHERE id = NEW.member_id
  FOR UPDATE;  -- Lock the row to prevent concurrent modifications

  -- Check if member exists
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member not found';
  END IF;

  -- Get daily check-ins count for the member (excluding current record)
  SELECT COUNT(*)
  INTO v_daily_check_ins
  FROM check_ins
  WHERE member_id = NEW.member_id
    AND check_in_date = NEW.check_in_date
    AND id IS DISTINCT FROM NEW.id  -- 排除当前记录
    AND NOT is_extra;  -- 只计算非额外签到

  -- Check if member has checked in for the same class type today
  SELECT EXISTS (
    SELECT 1
    FROM check_ins
    WHERE member_id = NEW.member_id
      AND check_in_date = NEW.check_in_date
      AND class_type = NEW.class_type
      AND id IS DISTINCT FROM NEW.id  -- 排除当前记录
  ) INTO v_has_same_class_check_in;

  -- Prevent duplicate check-ins for the same class type on the same day
  IF v_has_same_class_check_in THEN
    RAISE EXCEPTION 'Already checked in for this class type today';
  END IF;

  -- Log validation start
  INSERT INTO debug_logs (function_name, member_id, message, details)
  VALUES (
    'validate_check_in',
    NEW.member_id,
    '开始验证',
    jsonb_build_object(
      'member_id', NEW.member_id,
      'membership', v_member.membership,
      'remaining_classes', v_member.remaining_classes,
      'check_in_date', NEW.check_in_date
    )
  );

  -- Set is_extra based on membership type and status
  NEW.is_extra := CASE
    -- New member check-in
    WHEN v_member.is_new_member THEN true
    -- Class-based membership
    WHEN v_member.membership IN ('single_class', 'two_classes', 'ten_classes') THEN
      CASE
        WHEN v_member.remaining_classes <= 0 THEN true
        ELSE false
      END
    -- Monthly membership
    WHEN v_member.membership = 'single_monthly' THEN
      CASE
        WHEN v_daily_check_ins >= 1 THEN true
        ELSE false
      END
    WHEN v_member.membership = 'double_monthly' THEN
      CASE
        WHEN v_daily_check_ins >= 2 THEN true
        ELSE false
      END
    -- No valid membership
    ELSE true
  END;

  -- Log validation result
  INSERT INTO debug_logs (function_name, member_id, message, details)
  VALUES (
    'validate_check_in',
    NEW.member_id,
    '验证完成',
    jsonb_build_object(
      'is_extra', NEW.is_extra,
      'membership', v_member.membership,
      'remaining_classes', v_member.remaining_classes
    )
  );

  RETURN NEW;
END;
$function$; 