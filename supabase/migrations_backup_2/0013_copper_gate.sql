/*
  # Improve check-in validation

  1. Changes
    - Enhance check-in validation to prevent duplicate check-ins
    - Add clear error messages in both Chinese and English
    - Improve validation logic for different membership types

  2. Security
    - Maintain existing RLS policies
    - No changes to table permissions
*/

-- Enhanced check-in validation function
CREATE OR REPLACE FUNCTION validate_check_in()
RETURNS TRIGGER AS $$
DECLARE
  v_membership membership_type;
  v_membership_expiry timestamptz;
  v_same_class_check_ins int;
  v_total_daily_check_ins int;
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

  -- Count total check-ins for today
  SELECT COUNT(*)
  INTO v_total_daily_check_ins
  FROM check_ins
  WHERE member_id = NEW.member_id
  AND check_in_date = CURRENT_DATE;

  -- Prevent duplicate check-ins for the same class type
  IF v_same_class_check_ins > 0 THEN
    RAISE EXCEPTION '会员今日已在该时段签到，请选择其他时段。 Member has already checked in for this class type today, please choose another class time.';
  END IF;

  -- Additional validations based on membership type
  IF v_membership = 'single_daily_monthly' AND v_total_daily_check_ins >= 1 THEN
    RAISE EXCEPTION '日单月卡会员每天只能签到一次。 Single daily monthly members can only check in once per day.';
  END IF;

  IF v_membership = 'double_daily_monthly' AND v_total_daily_check_ins >= 2 THEN
    RAISE EXCEPTION '日多月卡会员每天最多签到两次。 Double daily monthly members can only check in twice per day.';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Update process_check_in function to focus on membership status
CREATE OR REPLACE FUNCTION process_check_in()
RETURNS TRIGGER AS $$
DECLARE
  v_membership membership_type;
  v_remaining_classes int;
  v_membership_expiry timestamptz;
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

  -- Set is_extra flag based on membership status
  IF v_membership IS NULL THEN
    NEW.is_extra := true;
  ELSIF v_membership IN ('single_daily_monthly', 'double_daily_monthly') THEN
    IF v_membership_expiry < CURRENT_DATE THEN
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