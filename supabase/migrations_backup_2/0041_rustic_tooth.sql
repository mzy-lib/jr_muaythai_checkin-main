BEGIN;

-- Add class time validation function
CREATE OR REPLACE FUNCTION validate_class_time(
  p_class_type class_type
) RETURNS boolean AS $$
BEGIN
  RETURN CASE p_class_type
    WHEN 'morning' THEN 
      EXTRACT(HOUR FROM CURRENT_TIME) BETWEEN 9 AND 10 AND
      EXTRACT(MINUTE FROM CURRENT_TIME) <= 30
    WHEN 'evening' THEN
      EXTRACT(HOUR FROM CURRENT_TIME) BETWEEN 17 AND 18 AND
      EXTRACT(MINUTE FROM CURRENT_TIME) <= 30
  END;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger and function
DROP TRIGGER IF EXISTS check_in_validation_trigger ON check_ins;
DROP FUNCTION IF EXISTS validate_check_in() CASCADE;

-- Enhanced check-in validation with time check
CREATE FUNCTION validate_check_in()
RETURNS TRIGGER AS $$
DECLARE
  v_member RECORD;
  v_same_class_check_ins int;
  v_is_valid_time boolean;
BEGIN
  -- Validate class time
  v_is_valid_time := validate_class_time(NEW.class_type);
  IF NOT v_is_valid_time THEN
    RAISE WARNING '当前不在课程时间范围内。Current time is outside class hours.';
  END IF;

  -- Lock member record
  SELECT *
  INTO v_member
  FROM members
  WHERE id = NEW.member_id
  FOR UPDATE;

  -- Prevent duplicate check-ins
  SELECT COUNT(*)
  INTO v_same_class_check_ins
  FROM check_ins
  WHERE member_id = NEW.member_id
    AND check_in_date = CURRENT_DATE
    AND class_type = NEW.class_type;

  IF v_same_class_check_ins > 0 THEN
    RAISE EXCEPTION '您今天已在该时段签到。You have already checked in for this class today.'
      USING HINT = 'duplicate_checkin';
  END IF;

  -- Always mark new members as extra check-ins
  IF v_member.is_new_member THEN
    NEW.is_extra := true;
    RETURN NEW;
  END IF;

  -- Set is_extra based on membership rules
  NEW.is_extra := CASE
    -- No membership
    WHEN v_member.membership IS NULL THEN
      true
    -- Monthly membership expired
    WHEN v_member.membership IN ('single_daily_monthly', 'double_daily_monthly')
      AND v_member.membership_expiry < CURRENT_DATE THEN
      true
    -- No remaining classes
    WHEN v_member.membership IN ('single_class', 'two_classes', 'ten_classes')
      AND v_member.remaining_classes <= 0 THEN
      true
    -- Valid membership
    ELSE
      false
  END;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate trigger
CREATE TRIGGER check_in_validation_trigger
  BEFORE INSERT ON check_ins
  FOR EACH ROW
  EXECUTE FUNCTION validate_check_in();

-- Add function comments
COMMENT ON FUNCTION validate_class_time(class_type) IS 
'Validates if current time is within allowed class hours:
Morning: 9:00-10:30
Evening: 17:00-18:30';

COMMENT ON FUNCTION validate_check_in() IS 
'Enhanced check-in validation with:
1. Class time validation
2. Duplicate check-in prevention
3. New member handling (always extra)
4. Membership status validation';

COMMIT;