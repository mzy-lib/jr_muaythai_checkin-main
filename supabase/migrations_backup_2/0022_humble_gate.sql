/*
  # Fix class-based membership check-in logic

  1. Changes
    - Fix remaining classes validation for class-based memberships
    - Add explicit check for positive remaining classes
    - Improve error handling for class-based memberships

  2. Security
    - Maintain existing RLS policies
    - No data loss operations
*/

-- Enhanced check-in processing with fixed class-based membership handling
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

  -- Set is_extra flag based on membership type
  CASE
    -- No membership
    WHEN v_membership IS NULL THEN
      NEW.is_extra := true;
    
    -- Monthly memberships
    WHEN v_membership IN ('single_daily_monthly', 'double_daily_monthly') THEN
      IF v_membership_expiry < CURRENT_DATE THEN
        NEW.is_extra := true;
      ELSE
        -- Count check-ins
        SELECT COUNT(*)
        INTO v_same_class_check_ins
        FROM check_ins
        WHERE member_id = NEW.member_id
        AND check_in_date = CURRENT_DATE
        AND class_type = NEW.class_type
        AND is_extra = false;

        SELECT COUNT(*)
        INTO v_daily_check_ins
        FROM check_ins
        WHERE member_id = NEW.member_id
        AND check_in_date = CURRENT_DATE
        AND is_extra = false;

        -- Determine if extra based on check-in counts
        IF v_same_class_check_ins > 0 THEN
          NEW.is_extra := true;
        ELSIF v_membership = 'single_daily_monthly' THEN
          NEW.is_extra := v_daily_check_ins >= 1;
        ELSIF v_membership = 'double_daily_monthly' AND v_daily_check_ins < 2 THEN
          NEW.is_extra := false;
        ELSE
          NEW.is_extra := true;
        END IF;
      END IF;
    
    -- Class-based memberships
    WHEN v_membership IN ('single_class', 'two_classes', 'ten_classes') THEN
      -- Explicitly check for positive remaining classes
      IF v_remaining_classes > 0 THEN
        NEW.is_extra := false;
      ELSE
        NEW.is_extra := true;
      END IF;
    
    -- Unknown membership type
    ELSE
      NEW.is_extra := true;
  END CASE;

  -- Update member information
  IF NOT NEW.is_extra THEN
    -- Only decrement for class-based memberships
    IF v_membership IN ('single_class', 'two_classes', 'ten_classes') THEN
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