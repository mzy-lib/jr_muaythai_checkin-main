-- Fix check-in logic to properly handle remaining classes
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
  WHERE id = NEW.member_id
  FOR UPDATE;  -- Lock the row to prevent race conditions

  -- Set is_extra flag based on membership type and status
  IF v_membership IS NULL THEN
    -- No membership
    NEW.is_extra := true;
  ELSIF v_membership IN ('single_daily_monthly', 'double_daily_monthly') THEN
    -- Monthly membership logic
    IF v_membership_expiry < CURRENT_DATE THEN
      NEW.is_extra := true;
    ELSE
      -- Count daily check-ins for monthly memberships
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
  ELSE
    -- Class-based membership logic (single_class, two_classes, ten_classes)
    -- Important: Check remaining classes BEFORE decrementing
    IF v_remaining_classes > 0 THEN
      NEW.is_extra := false;
    ELSE
      NEW.is_extra := true;
    END IF;
  END IF;

  -- Update member information AFTER setting is_extra flag
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