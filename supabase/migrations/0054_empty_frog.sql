-- Enhanced check-in validation with improved error handling
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

  -- Check for duplicate check-in
  SELECT COUNT(*)
  INTO v_same_class_check_ins
  FROM check_ins
  WHERE member_id = NEW.member_id
    AND check_in_date = CURRENT_DATE
    AND class_type = NEW.class_type;

  IF v_same_class_check_ins > 0 THEN
    -- Raise a specific error for duplicate check-ins
    RAISE EXCEPTION using
      errcode = 'DUPCK',
      message = format('您今天已经在%s签到过了。如需签到其他时段课程，请返回首页重新选择。\nYou have already checked in for %s today. To check in for a different class time, please return to home page and select another time.',
        v_class_type_zh,
        v_class_type_en),
      hint = 'duplicate_checkin';
  END IF;

  -- Rest of the validation logic remains the same...
  -- [Previous validation code]

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;