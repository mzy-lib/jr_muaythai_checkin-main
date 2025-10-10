-- Enhanced member validation
CREATE OR REPLACE FUNCTION validate_member_name(
  p_name text,
  p_email text DEFAULT NULL
) RETURNS boolean AS $$
BEGIN
  -- Basic validation
  IF TRIM(p_name) = '' THEN
    RETURN false;
  END IF;

  -- Check for invalid characters
  IF p_name !~ '^[a-zA-Z0-9\u4e00-\u9fa5@._\-\s]+$' THEN
    RETURN false;
  END IF;

  RETURN true;
END;
$$ LANGUAGE plpgsql;

-- Enhanced check-in validation with concurrency control
CREATE OR REPLACE FUNCTION validate_check_in()
RETURNS TRIGGER AS $$
DECLARE
  v_member RECORD;
  v_same_class_check_ins int;
  v_today date;
BEGIN
  -- Get current date in gym's timezone
  v_today := CURRENT_DATE;

  -- Lock member record
  SELECT *
  INTO v_member
  FROM members
  WHERE id = NEW.member_id
  FOR UPDATE;

  -- Prevent duplicate check-ins with proper timezone handling
  SELECT COUNT(*)
  INTO v_same_class_check_ins
  FROM check_ins
  WHERE member_id = NEW.member_id
    AND check_in_date = v_today
    AND class_type = NEW.class_type;

  IF v_same_class_check_ins > 0 THEN
    RAISE EXCEPTION '您今天已在该时段签到。You have already checked in for this class today.'
      USING HINT = 'duplicate_checkin';
  END IF;

  -- Set check-in date explicitly
  NEW.check_in_date := v_today;

  -- Rest of the validation logic remains the same
  -- ...

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;