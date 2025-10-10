/*
  # Fix double daily monthly check-in logic

  1. Changes
    - Fix check-in counting for double daily monthly members
    - Improve validation for different class types
    - Add better error handling

  2. Security
    - Maintain existing RLS policies
    - No data loss operations
*/

-- Enhanced check-in processing with fixed double daily monthly handling
CREATE OR REPLACE FUNCTION process_check_in()
RETURNS TRIGGER AS $$
DECLARE
  v_membership membership_type;
  v_remaining_classes int;
  v_membership_expiry timestamptz;
  v_daily_check_ins int;
  v_same_class_check_ins int;
BEGIN
  -- Get member details with row lock
  SELECT 
    membership,
    remaining_classes,
    membership_expiry
  INTO
    v_membership,
    v_remaining_classes,
    v_membership_expiry
  FROM members
  WHERE id = NEW.member_id
  FOR UPDATE;

  -- Monthly membership validation
  IF v_membership IN ('single_daily_monthly', 'double_daily_monthly') THEN
    -- First check if membership is expired
    IF v_membership_expiry < CURRENT_DATE THEN
      NEW.is_extra := true;
    ELSE
      -- Count non-extra check-ins for today for this specific class type
      SELECT COUNT(*)
      INTO v_same_class_check_ins
      FROM check_ins
      WHERE member_id = NEW.member_id
      AND check_in_date = CURRENT_DATE
      AND class_type = NEW.class_type
      AND is_extra = false;

      -- Count total non-extra check-ins for today
      SELECT COUNT(*)
      INTO v_daily_check_ins
      FROM check_ins
      WHERE member_id = NEW.member_id
      AND check_in_date = CURRENT_DATE
      AND is_extra = false;

      -- Set is_extra based on membership type and check-in counts
      IF v_same_class_check_ins > 0 THEN
        -- Already checked in for this class type today
        NEW.is_extra := true;
      ELSIF v_membership = 'single_daily_monthly' THEN
        -- Single daily can only check in once per day
        NEW.is_extra := v_daily_check_ins >= 1;
      ELSIF v_membership = 'double_daily_monthly' AND v_daily_check_ins < 2 THEN
        -- Double daily can check in twice per day in different class types
        NEW.is_extra := false;
      ELSE
        -- All other cases are extra check-ins
        NEW.is_extra := true;
      END IF;
    END IF;
  -- Class-based membership validation
  ELSIF v_membership IN ('single_class', 'two_classes', 'ten_classes') THEN
    NEW.is_extra := v_remaining_classes <= 0;
  -- No membership
  ELSE
    NEW.is_extra := true;
  END IF;

  -- Update member information
  IF NOT NEW.is_extra THEN
    IF v_membership NOT IN ('single_daily_monthly', 'double_daily_monthly') 
    AND v_membership IS NOT NULL THEN
      UPDATE members
      SET remaining_classes = remaining_classes - 1
      WHERE id = NEW.member_id;
    END IF;
  ELSE
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