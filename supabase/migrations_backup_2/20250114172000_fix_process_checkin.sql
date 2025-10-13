CREATE OR REPLACE FUNCTION process_check_in()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
  v_member RECORD;
BEGIN
  -- Lock the member record to prevent concurrent updates
  SELECT *
  INTO v_member
  FROM members
  WHERE id = NEW.member_id
  FOR UPDATE;  -- Add row-level lock

  -- Update member information in a single atomic operation
  UPDATE members
  SET
    -- Update remaining classes for class-based memberships
    remaining_classes = CASE
      WHEN membership IN ('single_class', 'two_classes', 'ten_classes')
        AND NOT NEW.is_extra  -- Only deduct if not extra check-in
        AND remaining_classes > 0  -- Only deduct if has remaining classes
      THEN remaining_classes - 1
      ELSE remaining_classes
    END,
    -- Update last check-in date
    last_check_in_date = NEW.check_in_date,
    -- Update daily check-ins counter
    daily_check_ins = CASE
      WHEN last_check_in_date = NEW.check_in_date THEN daily_check_ins + 1
      ELSE 1
    END,
    -- Update extra check-ins counter
    extra_check_ins = CASE
      WHEN NEW.is_extra THEN extra_check_ins + 1
      ELSE extra_check_ins
    END,
    -- Remove new member status after first check-in
    is_new_member = false
  WHERE id = NEW.member_id;

  -- Log the update for debugging
  INSERT INTO debug_logs (function_name, member_id, message, details)
  VALUES (
    'process_check_in',
    NEW.member_id,
    '处理签到',
    jsonb_build_object(
      'is_extra', NEW.is_extra,
      'old_remaining_classes', v_member.remaining_classes,
      'membership', v_member.membership
    )
  );

  RETURN NEW;
END;
$function$; 