/*
  # Fix double daily membership check-in logic

  1. Changes
    - Update check-in trigger to properly handle double daily memberships
    - Count check-ins separately for morning and evening classes
    - Ensure proper handling of same-class-type check-ins

  2. Technical Details
    - Modify process_check_in() function to check class type
    - Add validation for repeated class type check-ins
*/

CREATE OR REPLACE FUNCTION process_check_in()
RETURNS TRIGGER AS $$
BEGIN
  -- Get member details
  DECLARE
    v_membership membership_type;
    v_remaining_classes int;
    v_membership_expiry timestamptz;
    v_same_class_check_ins int;
  BEGIN
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

    -- Count check-ins for the same class type today
    SELECT COUNT(*)
    INTO v_same_class_check_ins
    FROM check_ins
    WHERE member_id = NEW.member_id
    AND check_in_date = CURRENT_DATE
    AND class_type = NEW.class_type
    AND is_extra = false;

    -- Set is_extra flag based on membership type and status
    IF v_membership IS NULL THEN
      NEW.is_extra := true;
    ELSIF v_membership IN ('single_daily_monthly', 'double_daily_monthly') THEN
      IF v_membership_expiry < CURRENT_DATE THEN
        NEW.is_extra := true;
      ELSIF v_same_class_check_ins > 0 THEN
        -- Already checked in for this class type today
        NEW.is_extra := true;
      ELSE
        NEW.is_extra := false;
      END IF;
    ELSIF v_remaining_classes <= 0 THEN
      NEW.is_extra := true;
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
END;
$$ LANGUAGE plpgsql;