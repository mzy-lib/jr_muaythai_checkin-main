CREATE OR REPLACE FUNCTION validate_check_in()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
  v_member RECORD;
  v_daily_check_ins integer;
  v_same_class_check_ins integer;
BEGIN
  -- Get member details
  SELECT *
  INTO v_member
  FROM members
  WHERE id = NEW.member_id;

  -- Check if member exists
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member not found';
  END IF;

  -- Get daily check-ins count for the member
  SELECT COUNT(*)
  INTO v_daily_check_ins
  FROM check_ins
  WHERE member_id = NEW.member_id
    AND check_in_date = NEW.check_in_date;

  -- Get same class type check-ins count for the member on the same day
  SELECT COUNT(*)
  INTO v_same_class_check_ins
  FROM check_ins
  WHERE member_id = NEW.member_id
    AND check_in_date = NEW.check_in_date
    AND class_type = NEW.class_type;

  -- Prevent duplicate check-ins for the same class type on the same day
  IF v_same_class_check_ins > 0 THEN
    RAISE EXCEPTION 'Already checked in for this class type today';
  END IF;

  -- Set is_extra based on different scenarios
  NEW.is_extra := CASE
    -- New member: first check-in is extra
    WHEN v_member.is_new_member = true THEN true
    
    -- Monthly membership scenarios
    WHEN v_member.membership = 'single_monthly' THEN
      CASE
        -- Expired membership
        WHEN v_member.membership_expiry < CURRENT_TIMESTAMP THEN true
        -- Over daily limit (1 class per day)
        WHEN v_daily_check_ins >= 1 THEN true
        ELSE false
      END
    WHEN v_member.membership = 'double_monthly' THEN
      CASE
        -- Expired membership
        WHEN v_member.membership_expiry < CURRENT_TIMESTAMP THEN true
        -- Over daily limit (2 classes per day)
        WHEN v_daily_check_ins >= 2 THEN true
        ELSE false
      END
      
    -- Class package scenarios
    WHEN v_member.membership IN ('single_class', 'two_classes', 'ten_classes') THEN
      CASE
        -- No remaining classes
        WHEN v_member.remaining_classes <= 0 THEN true
        ELSE false
      END
      
    -- No valid membership
    ELSE true
  END;

  RETURN NEW;
END;
$function$; 