/*
  # Comprehensive check-in system fixes

  1. Changes
    - Consolidate duplicate check-in validation
    - Fix monthly membership check-in counting
    - Improve class-based membership handling
    - Enhance transaction safety
    - Add detailed error messages

  2. Security
    - Maintain existing RLS policies
    - Add row-level locking for consistency
*/

-- Enhanced check-in validation
CREATE OR REPLACE FUNCTION validate_check_in()
RETURNS TRIGGER AS $$
DECLARE
  v_membership membership_type;
  v_membership_expiry timestamptz;
  v_remaining_classes int;
  v_same_class_check_ins int;
  v_daily_check_ins int;
BEGIN
  -- Get member details with lock
  SELECT 
    membership,
    membership_expiry,
    remaining_classes
  INTO
    v_membership,
    v_membership_expiry,
    v_remaining_classes
  FROM members
  WHERE id = NEW.member_id
  FOR UPDATE;

  -- Validate based on membership type
  CASE
    -- Monthly memberships
    WHEN v_membership IN ('single_daily_monthly', 'double_daily_monthly') THEN
      -- Check expiry
      IF v_membership_expiry < CURRENT_DATE THEN
        RAISE EXCEPTION '会员卡已过期。Membership has expired.'
          USING HINT = 'expired_membership';
      END IF;

      -- Check same class type check-ins
      SELECT COUNT(*)
      INTO v_same_class_check_ins
      FROM check_ins
      WHERE member_id = NEW.member_id
        AND check_in_date = CURRENT_DATE
        AND class_type = NEW.class_type
        AND is_extra = false;

      IF v_same_class_check_ins > 0 THEN
        RAISE EXCEPTION '已在该时段签到。Already checked in for this class type today.'
          USING HINT = 'duplicate_class';
      END IF;

      -- Check daily limits
      SELECT COUNT(*)
      INTO v_daily_check_ins
      FROM check_ins
      WHERE member_id = NEW.member_id
        AND check_in_date = CURRENT_DATE
        AND is_extra = false;

      IF v_membership = 'single_daily_monthly' AND v_daily_check_ins >= 1 THEN
        RAISE EXCEPTION '今日签到次数已达上限。Daily check-in limit reached.'
          USING HINT = 'daily_limit';
      END IF;

      IF v_membership = 'double_daily_monthly' AND v_daily_check_ins >= 2 THEN
        RAISE EXCEPTION '今日签到次数已达上限。Daily check-in limit reached.'
          USING HINT = 'daily_limit';
      END IF;

    -- Class-based memberships
    WHEN v_membership IN ('single_class', 'two_classes', 'ten_classes') THEN
      IF v_remaining_classes <= 0 THEN
        RAISE EXCEPTION '剩余课时不足。No remaining classes.'
          USING HINT = 'no_classes';
      END IF;

      -- Check for duplicate class type
      SELECT COUNT(*)
      INTO v_same_class_check_ins
      FROM check_ins
      WHERE member_id = NEW.member_id
        AND check_in_date = CURRENT_DATE
        AND class_type = NEW.class_type
        AND is_extra = false;

      IF v_same_class_check_ins > 0 THEN
        RAISE EXCEPTION '已在该时段签到。Already checked in for this class type today.'
          USING HINT = 'duplicate_class';
      END IF;
  END CASE;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Enhanced check-in processing
CREATE OR REPLACE FUNCTION process_check_in()
RETURNS TRIGGER AS $$
DECLARE
  v_membership membership_type;
  v_remaining_classes int;
  v_membership_expiry timestamptz;
BEGIN
  -- Get member details with lock
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

  -- Set is_extra flag
  NEW.is_extra := CASE
    -- No membership
    WHEN v_membership IS NULL THEN 
      true
    -- Expired monthly membership
    WHEN v_membership IN ('single_daily_monthly', 'double_daily_monthly') 
      AND v_membership_expiry < CURRENT_DATE THEN 
      true
    -- No remaining classes
    WHEN v_membership IN ('single_class', 'two_classes', 'ten_classes') 
      AND v_remaining_classes <= 0 THEN
      true
    -- Valid membership
    ELSE 
      false
  END;

  -- Update member information
  IF NOT NEW.is_extra THEN
    -- Decrement remaining classes for class-based memberships
    IF v_membership IN ('single_class', 'two_classes', 'ten_classes') THEN
      UPDATE members
      SET remaining_classes = remaining_classes - 1
      WHERE id = NEW.member_id;
    END IF;
  ELSE
    -- Increment extra check-ins counter
    UPDATE members
    SET extra_check_ins = extra_check_ins + 1
    WHERE id = NEW.member_id;
  END IF;

  -- Update new member status
  UPDATE members
  SET is_new_member = false
  WHERE id = NEW.member_id
    AND is_new_member = true;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate triggers
DROP TRIGGER IF EXISTS check_in_validation_trigger ON check_ins;
CREATE TRIGGER check_in_validation_trigger
  BEFORE INSERT ON check_ins
  FOR EACH ROW
  EXECUTE FUNCTION validate_check_in();

DROP TRIGGER IF EXISTS check_in_processing_trigger ON check_ins;
CREATE TRIGGER check_in_processing_trigger
  BEFORE INSERT ON check_ins
  FOR EACH ROW
  EXECUTE FUNCTION process_check_in();