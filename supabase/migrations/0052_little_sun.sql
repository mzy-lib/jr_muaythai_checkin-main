-- Enhanced check-in validation with improved duplicate handling
CREATE OR REPLACE FUNCTION validate_check_in()
RETURNS TRIGGER AS $$
DECLARE
  v_member RECORD;
  v_same_class_check_ins int;
  v_daily_check_ins int;
  v_class_type_zh text;
  v_class_type_en text;
BEGIN
  -- Lock member record
  SELECT *
  INTO v_member
  FROM members
  WHERE id = NEW.member_id
  FOR UPDATE;

  -- Set class type text for error messages
  v_class_type_zh := CASE NEW.class_type 
    WHEN 'morning' THEN '早课'
    WHEN 'evening' THEN '晚课'
  END;
  
  v_class_type_en := CASE NEW.class_type
    WHEN 'morning' THEN 'morning class'
    WHEN 'evening' THEN 'evening class'
  END;

  -- Check for duplicate check-in with improved message
  SELECT COUNT(*)
  INTO v_same_class_check_ins
  FROM check_ins
  WHERE member_id = NEW.member_id
    AND check_in_date = CURRENT_DATE
    AND class_type = NEW.class_type;

  IF v_same_class_check_ins > 0 THEN
    RAISE EXCEPTION E'您今天已经在%签到过了。如需签到其他时段课程，请返回首页重新选择。\nYou have already checked in for % today. To check in for a different class time, please return to home page and select another time.',
      v_class_type_zh,
      v_class_type_en
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
    WHEN v_member.is_new_member OR v_member.membership IS NULL THEN
      true
    WHEN v_member.membership IN ('single_daily_monthly', 'double_daily_monthly') THEN
      CASE
        WHEN v_member.membership_expiry < CURRENT_DATE THEN 
          true
        WHEN v_member.membership = 'single_daily_monthly' AND v_daily_check_ins >= 1 THEN
          true
        WHEN v_member.membership = 'double_daily_monthly' AND v_daily_check_ins >= 2 THEN
          true
        ELSE
          false
      END
    WHEN v_member.membership IN ('single_class', 'two_classes', 'ten_classes') THEN
      v_member.remaining_classes <= 0
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
- Consistent bilingual error messages
- Clear class type indication
- Proper membership status handling
- Atomic transaction handling';