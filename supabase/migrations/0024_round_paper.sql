/*
  # Fix check-in validation logic

  1. Changes
    - Prevent duplicate check-ins for the same class type on the same day
    - Improve error messages for better user experience
    - Separate validation logic from processing logic
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

  -- Always check for duplicate class type first
  SELECT COUNT(*)
  INTO v_same_class_check_ins
  FROM check_ins
  WHERE member_id = NEW.member_id
    AND check_in_date = CURRENT_DATE
    AND class_type = NEW.class_type;

  IF v_same_class_check_ins > 0 THEN
    RAISE EXCEPTION '您今天已在该时段签到。请返回首页选择其他时段。You have already checked in for this class type today. Please return home and choose another class time.'
      USING HINT = 'duplicate_class';
  END IF;

  -- Then validate based on membership type
  CASE
    -- Monthly memberships
    WHEN v_membership IN ('single_daily_monthly', 'double_daily_monthly') THEN
      -- Check expiry
      IF v_membership_expiry < CURRENT_DATE THEN
        RAISE EXCEPTION '会员卡已过期。请联系管理员续费。Membership has expired. Please contact admin to renew.'
          USING HINT = 'expired_membership';
      END IF;

      -- Check daily limits
      SELECT COUNT(*)
      INTO v_daily_check_ins
      FROM check_ins
      WHERE member_id = NEW.member_id
        AND check_in_date = CURRENT_DATE;

      IF v_membership = 'single_daily_monthly' AND v_daily_check_ins >= 1 THEN
        RAISE EXCEPTION '今日签到次数已达上限。请明天再来。Daily check-in limit reached. Please come back tomorrow.'
          USING HINT = 'daily_limit';
      END IF;

      IF v_membership = 'double_daily_monthly' AND v_daily_check_ins >= 2 THEN
        RAISE EXCEPTION '今日签到次数已达上限。请明天再来。Daily check-in limit reached. Please come back tomorrow.'
          USING HINT = 'daily_limit';
      END IF;

    -- Class-based memberships
    WHEN v_membership IN ('single_class', 'two_classes', 'ten_classes') THEN
      IF v_remaining_classes <= 0 THEN
        RAISE EXCEPTION '剩余课时不足。请联系管理员购买新的课程包。No remaining classes. Please contact admin to purchase more classes.'
          USING HINT = 'no_classes';
      END IF;

    -- No membership
    WHEN v_membership IS NULL THEN
      RAISE EXCEPTION '您还没有会员卡。请联系管理员购买会员卡。No active membership. Please contact admin to purchase a membership.'
        USING HINT = 'no_membership';
  END CASE;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Simplified check-in processing (only handles successful check-ins)
CREATE OR REPLACE FUNCTION process_check_in()
RETURNS TRIGGER AS $$
DECLARE
  v_membership membership_type;
  v_remaining_classes int;
BEGIN
  -- Get member details
  SELECT 
    membership,
    remaining_classes
  INTO
    v_membership,
    v_remaining_classes
  FROM members
  WHERE id = NEW.member_id;

  -- Update member information
  IF v_membership IN ('single_class', 'two_classes', 'ten_classes') THEN
    -- Decrement remaining classes for class-based memberships
    UPDATE members
    SET remaining_classes = remaining_classes - 1
    WHERE id = NEW.member_id;
  END IF;

  -- Update new member status
  UPDATE members
  SET is_new_member = false
  WHERE id = NEW.member_id
    AND is_new_member = true;

  -- All check-ins that pass validation are regular check-ins
  NEW.is_extra := false;
  
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