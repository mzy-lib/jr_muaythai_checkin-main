-- Fix membership type names in validate_check_in function
BEGIN;

CREATE OR REPLACE FUNCTION validate_check_in()
RETURNS TRIGGER AS $$
DECLARE
  v_member RECORD;
  v_daily_check_ins integer;
BEGIN
  -- Get member details
  SELECT *
  INTO v_member
  FROM members
  WHERE id = NEW.member_id;

  -- Count today's regular check-ins
  SELECT COUNT(*)
  INTO v_daily_check_ins
  FROM check_ins
  WHERE member_id = NEW.member_id
    AND check_in_date = CURRENT_DATE
    AND is_extra = false;

  -- Set is_extra based on membership rules
  NEW.is_extra := CASE
    -- New member or no membership
    WHEN v_member.is_new_member OR v_member.membership IS NULL THEN
      true
    -- Monthly memberships
    WHEN v_member.membership IN ('single_monthly', 'double_monthly') THEN
      CASE
        -- Expired membership
        WHEN v_member.membership_expiry < CURRENT_DATE THEN 
          true
        -- Single monthly reached limit
        WHEN v_member.membership = 'single_monthly' AND v_daily_check_ins >= 1 THEN
          true
        -- Double monthly reached limit
        WHEN v_member.membership = 'double_monthly' AND v_daily_check_ins >= 2 THEN
          true
        -- Within limits
        ELSE
          false
      END
    -- Class-based memberships
    WHEN v_member.membership IN ('single_class', 'two_classes', 'ten_classes') THEN
      v_member.remaining_classes <= 0
    -- Unknown membership type (safety)
    ELSE
      true
  END;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMIT;