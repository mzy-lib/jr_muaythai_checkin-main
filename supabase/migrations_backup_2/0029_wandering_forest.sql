-- Enhanced check-in validation to allow members without membership
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
        NEW.is_extra := true;
      ELSE
        -- Check daily limits
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
      IF v_remaining_classes <= 0 THEN
        NEW.is_extra := true;
      ELSE
        NEW.is_extra := false;
      END IF;

    -- No membership
    WHEN v_membership IS NULL THEN
      NEW.is_extra := true;
  END CASE;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Update process_check_in to handle extra check-ins
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
  IF NOT NEW.is_extra AND v_membership IN ('single_class', 'two_classes', 'ten_classes') THEN
    -- Decrement remaining classes for class-based memberships
    UPDATE members
    SET remaining_classes = remaining_classes - 1
    WHERE id = NEW.member_id;
  END IF;

  IF NEW.is_extra THEN
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