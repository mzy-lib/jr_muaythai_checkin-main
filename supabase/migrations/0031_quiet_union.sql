-- Enhanced check-in validation with updated new member handling
CREATE OR REPLACE FUNCTION validate_check_in()
RETURNS TRIGGER AS $$
DECLARE
  v_membership membership_type;
  v_membership_expiry timestamptz;
  v_remaining_classes int;
  v_same_class_check_ins int;
  v_daily_check_ins int;
  v_is_new_member boolean;
BEGIN
  -- Get member details with lock
  SELECT 
    membership,
    membership_expiry,
    remaining_classes,
    is_new_member
  INTO
    v_membership,
    v_membership_expiry,
    v_remaining_classes,
    v_is_new_member
  FROM members
  WHERE id = NEW.member_id
  FOR UPDATE;

  -- Check for duplicate class type
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

  -- All new members are marked as extra check-ins
  IF v_is_new_member THEN
    NEW.is_extra := true;
    RETURN NEW;
  END IF;

  -- Then validate based on membership type
  CASE
    -- Monthly memberships
    WHEN v_membership IN ('single_daily_monthly', 'double_daily_monthly') THEN
      IF v_membership_expiry < CURRENT_DATE THEN
        NEW.is_extra := true;
      ELSE
        SELECT COUNT(*)
        INTO v_daily_check_ins
        FROM check_ins
        WHERE member_id = NEW.member_id
          AND check_in_date = CURRENT_DATE
          AND is_extra = false;

        IF v_membership = 'single_daily_monthly' AND v_daily_check_ins >= 1 THEN
          NEW.is_extra := true;
        ELSIF v_membership = 'double_daily_monthly' AND v_daily_check_ins >= 2 THEN
          NEW.is_extra := true;
        ELSE
          NEW.is_extra := false;
        END IF;
      END IF;

    -- Class-based memberships
    WHEN v_membership IN ('single_class', 'two_classes', 'ten_classes') THEN
      NEW.is_extra := v_remaining_classes <= 0;

    -- No membership
    ELSE
      NEW.is_extra := true;
  END CASE;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;