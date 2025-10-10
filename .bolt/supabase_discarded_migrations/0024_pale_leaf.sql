/*
  # Fix check-in validation function

  1. Changes
    - Add missing ELSE clause to CASE statement
    - Improve validation for non-membership cases
    - Add comprehensive error handling
*/

-- Enhanced check-in validation with complete CASE handling
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

    -- No membership or other cases
    ELSE
      -- Allow check-in but it will be marked as extra
      NULL;
  END CASE;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;