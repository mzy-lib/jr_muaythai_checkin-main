-- Enhanced check-in validation with improved error messages
CREATE OR REPLACE FUNCTION validate_check_in()
RETURNS TRIGGER AS $$
DECLARE
  v_member RECORD;
  v_same_class_check_ins int;
  v_daily_check_ins int;
BEGIN
  -- Lock member record
  SELECT *
  INTO v_member
  FROM members
  WHERE id = NEW.member_id
  FOR UPDATE;

  -- Check for duplicate check-in with improved message
  SELECT COUNT(*)
  INTO v_same_class_check_ins
  FROM check_ins
  WHERE member_id = NEW.member_id
    AND check_in_date = CURRENT_DATE
    AND class_type = NEW.class_type;

  IF v_same_class_check_ins > 0 THEN
    -- More specific and helpful error message
    RAISE EXCEPTION '您今天已经在%课签到过了。如需签到其他时段课程，请返回首页重新选择。
You have already checked in for % class today. To check in for a different class time, please return to home page and select another time.',
      CASE NEW.class_type 
        WHEN 'morning' THEN '早'
        WHEN 'evening' THEN '晚'
      END,
      CASE NEW.class_type
        WHEN 'morning' THEN 'morning'
        WHEN 'evening' THEN 'evening'
      END
    USING HINT = 'duplicate_checkin';
  END IF;

  -- Count daily check-ins for monthly memberships
  IF v_member.membership IN ('single_daily_monthly', 'double_daily_monthly') THEN
    SELECT COUNT(*)
    INTO v_daily_check_ins
    FROM check_ins
    WHERE member_id = NEW.member_id
      AND check_in_date = CURRENT_DATE
      AND is_extra = false;
  END IF;

  -- Set is_extra based on membership rules
  NEW.is_extra := CASE
    -- New member or no membership
    WHEN v_member.is_new_member OR v_member.membership IS NULL THEN
      true
    -- Monthly memberships
    WHEN v_member.membership IN ('single_daily_monthly', 'double_daily_monthly') THEN
      CASE
        -- Expired membership
        WHEN v_member.membership_expiry < CURRENT_DATE THEN 
          true
        -- Single daily reached limit
        WHEN v_member.membership = 'single_daily_monthly' AND v_daily_check_ins >= 1 THEN
          true
        -- Double daily reached limit
        WHEN v_member.membership = 'double_daily_monthly' AND v_daily_check_ins >= 2 THEN
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

-- Add comment
COMMENT ON FUNCTION validate_check_in IS 
'Enhanced check-in validation with:
- Improved duplicate check-in error messages
- Clear indication of class type in error message
- Proper handling of membership status
- Atomic transaction handling';