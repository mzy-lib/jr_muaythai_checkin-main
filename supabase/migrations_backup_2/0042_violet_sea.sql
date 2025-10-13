BEGIN;

-- Drop the time validation function since it's no longer needed
DROP FUNCTION IF EXISTS validate_class_time(class_type);

-- Drop existing trigger and function
DROP TRIGGER IF EXISTS check_in_validation_trigger ON check_ins;
DROP FUNCTION IF EXISTS validate_check_in() CASCADE;

-- Updated check-in validation without time restrictions
CREATE FUNCTION validate_check_in()
RETURNS TRIGGER AS $$
DECLARE
  v_member RECORD;
  v_same_class_check_ins int;
BEGIN
  -- Lock member record
  SELECT *
  INTO v_member
  FROM members
  WHERE id = NEW.member_id
  FOR UPDATE;

  -- Prevent duplicate check-ins for same class type on same day
  SELECT COUNT(*)
  INTO v_same_class_check_ins
  FROM check_ins
  WHERE member_id = NEW.member_id
    AND check_in_date = CURRENT_DATE
    AND class_type = NEW.class_type;

  IF v_same_class_check_ins > 0 THEN
    RAISE EXCEPTION '您今天已在该时段签到。You have already checked in for this class type today.'
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

-- Update function comment
COMMENT ON FUNCTION validate_check_in() IS 
'Check-in validation with:
1. Same-day duplicate check-in prevention
2. New member handling (always extra)
3. Membership status validation';

COMMIT;