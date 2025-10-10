/*
  # Fix check-in validation logic

  1. Changes
    - Prevent duplicate check-ins for the same class type on the same day
    - Simplify check-in validation logic
    - Update error messages to be more clear

  2. Technical Details
    - Create new validate_check_in() function
    - Add trigger to run validation before check-in
    - Remove duplicate check-in handling from process_check_in()
*/

-- Function to validate check-ins
CREATE OR REPLACE FUNCTION validate_check_in()
RETURNS TRIGGER AS $$
DECLARE
  v_membership membership_type;
  v_membership_expiry timestamptz;
  v_same_class_check_ins int;
BEGIN
  -- Get member details
  SELECT 
    membership,
    membership_expiry
  INTO
    v_membership,
    v_membership_expiry
  FROM members
  WHERE id = NEW.member_id;

  -- Count check-ins for the same class type today
  SELECT COUNT(*)
  INTO v_same_class_check_ins
  FROM check_ins
  WHERE member_id = NEW.member_id
  AND check_in_date = CURRENT_DATE
  AND class_type = NEW.class_type;

  -- Prevent duplicate check-ins
  IF v_same_class_check_ins > 0 THEN
    RAISE EXCEPTION '会员今日已在该时段签到，请选择其他时段。 Member has already checked in for this class type today, please choose another class time.';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for check-in validation
DROP TRIGGER IF EXISTS check_in_validation_trigger ON check_ins;
CREATE TRIGGER check_in_validation_trigger
  BEFORE INSERT ON check_ins
  FOR EACH ROW
  EXECUTE FUNCTION validate_check_in();

-- Update process_check_in function to remove duplicate handling
CREATE OR REPLACE FUNCTION process_check_in()
RETURNS TRIGGER AS $$
DECLARE
  v_membership membership_type;
  v_remaining_classes int;
  v_membership_expiry timestamptz;
  v_daily_check_ins int;
BEGIN
  -- Get member details
  SELECT 
    membership,
    remaining_classes,
    membership_expiry
  INTO
    v_membership,
    v_remaining_classes,
    v_membership_expiry
  FROM members
  WHERE id = NEW.member_id;

  -- Count total daily check-ins
  SELECT COUNT(*)
  INTO v_daily_check_ins
  FROM check_ins
  WHERE member_id = NEW.member_id
  AND check_in_date = CURRENT_DATE;

  -- Set is_extra flag based on membership type and status
  IF v_membership IS NULL THEN
    NEW.is_extra := true;
  ELSIF v_membership IN ('single_daily_monthly', 'double_daily_monthly') THEN
    IF v_membership_expiry < CURRENT_DATE THEN
      NEW.is_extra := true;
    ELSIF v_membership = 'single_daily_monthly' AND v_daily_check_ins >= 1 THEN
      NEW.is_extra := true;
    ELSIF v_membership = 'double_daily_monthly' AND v_daily_check_ins >= 2 THEN
      NEW.is_extra := true;
    ELSE
      NEW.is_extra := false;
    END IF;
  ELSIF v_remaining_classes <= 0 THEN
    NEW.is_extra := true;
  ELSE
    NEW.is_extra := false;
  END IF;

  -- Update member information
  IF NOT NEW.is_extra AND v_membership NOT IN ('single_daily_monthly', 'double_daily_monthly') THEN
    UPDATE members
    SET remaining_classes = remaining_classes - 1
    WHERE id = NEW.member_id;
  END IF;

  IF NEW.is_extra THEN
    UPDATE members
    SET extra_check_ins = extra_check_ins + 1
    WHERE id = NEW.member_id;
  END IF;

  -- Update new member status
  IF (SELECT is_new_member FROM members WHERE id = NEW.member_id) THEN
    UPDATE members
    SET is_new_member = false
    WHERE id = NEW.member_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;