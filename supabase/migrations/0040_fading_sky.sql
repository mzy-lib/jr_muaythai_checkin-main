-- Drop existing functions first
DROP FUNCTION IF EXISTS find_member_for_checkin(text, text);
DROP FUNCTION IF EXISTS validate_check_in() CASCADE;
DROP FUNCTION IF EXISTS process_check_in() CASCADE;

-- Simplified member search with clear error handling
CREATE OR REPLACE FUNCTION find_member_for_checkin(
  p_name text,
  p_email text DEFAULT NULL
)
RETURNS TABLE (
  member_id uuid,
  is_new boolean,
  needs_email boolean
) AS $$
DECLARE
  v_member_count int;
BEGIN
  -- Basic input validation
  IF TRIM(p_name) = '' THEN
    RAISE EXCEPTION '请输入姓名。Please enter a name.'
      USING HINT = 'invalid_input';
  END IF;

  -- Email provided - exact match only
  IF p_email IS NOT NULL THEN
    RETURN QUERY
    SELECT 
      m.id,
      m.is_new_member,
      false::boolean
    FROM members m
    WHERE LOWER(TRIM(m.name)) = LOWER(TRIM(p_name))
      AND LOWER(TRIM(m.email)) = LOWER(TRIM(p_email));
    
    IF FOUND THEN
      RETURN;
    END IF;
  END IF;

  -- Count exact name matches
  SELECT COUNT(*) INTO v_member_count
  FROM members
  WHERE LOWER(TRIM(name)) = LOWER(TRIM(p_name));

  -- Handle results
  IF v_member_count > 1 THEN
    -- Multiple matches - require email
    RETURN QUERY SELECT NULL::uuid, false::boolean, true::boolean;
  ELSIF v_member_count = 1 THEN
    -- Single match
    RETURN QUERY
    SELECT 
      m.id,
      m.is_new_member,
      false::boolean
    FROM members m
    WHERE LOWER(TRIM(m.name)) = LOWER(TRIM(p_name));
  ELSE
    -- No match - new member
    RETURN QUERY SELECT NULL::uuid, true::boolean, false::boolean;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Core check-in validation focused on essential rules
CREATE OR REPLACE FUNCTION validate_check_in()
RETURNS TRIGGER AS $$
DECLARE
  v_member RECORD;
  v_same_class_check_ins int;
BEGIN
  -- Lock member record
  SELECT *
  INTO v_member
  FROM members
  WHERE id = NEW.member_id
  FOR UPDATE;

  -- Prevent duplicate check-ins
  SELECT COUNT(*)
  INTO v_same_class_check_ins
  FROM check_ins
  WHERE member_id = NEW.member_id
    AND check_in_date = CURRENT_DATE
    AND class_type = NEW.class_type;

  IF v_same_class_check_ins > 0 THEN
    RAISE EXCEPTION '您今天已在该时段签到。You have already checked in for this class today.'
      USING HINT = 'duplicate_checkin';
  END IF;

  -- Set is_extra based on simple rules
  NEW.is_extra := CASE
    -- New member or no membership
    WHEN v_member.is_new_member OR v_member.membership IS NULL THEN
      true
    -- Monthly membership expired
    WHEN v_member.membership IN ('single_daily_monthly', 'double_daily_monthly')
      AND v_member.membership_expiry < CURRENT_DATE THEN
      true
    -- No remaining classes
    WHEN v_member.membership IN ('single_class', 'two_classes', 'ten_classes')
      AND v_member.remaining_classes <= 0 THEN
      true
    -- Valid membership
    ELSE
      false
  END;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Simplified check-in processing
CREATE OR REPLACE FUNCTION process_check_in()
RETURNS TRIGGER AS $$
BEGIN
  -- Update member information in a single transaction
  IF NOT NEW.is_extra THEN
    UPDATE members
    SET 
      remaining_classes = CASE 
        WHEN membership IN ('single_class', 'two_classes', 'ten_classes') THEN
          remaining_classes - 1
        ELSE
          remaining_classes
      END,
      is_new_member = false
    WHERE id = NEW.member_id;
  ELSE
    UPDATE members
    SET 
      extra_check_ins = extra_check_ins + 1,
      is_new_member = false
    WHERE id = NEW.member_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate triggers
CREATE TRIGGER check_in_validation_trigger
  BEFORE INSERT ON check_ins
  FOR EACH ROW
  EXECUTE FUNCTION validate_check_in();

CREATE TRIGGER check_in_processing_trigger
  BEFORE INSERT ON check_ins
  FOR EACH ROW
  EXECUTE FUNCTION process_check_in();

-- Add function comments
COMMENT ON FUNCTION find_member_for_checkin(text, text) IS 
'Core member search functionality for check-in process.
Handles exact matches and duplicate names with clear error responses.';

COMMENT ON FUNCTION validate_check_in() IS 
'Essential check-in validation focusing on preventing duplicates
and determining if check-in should be marked as extra.';

COMMENT ON FUNCTION process_check_in() IS 
'Processes successful check-ins by updating member information
in a single atomic transaction.';