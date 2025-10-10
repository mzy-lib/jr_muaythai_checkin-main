-- Enhanced check-in validation and processing
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

  -- Check for duplicate check-in
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

-- Enhanced check-in processing
CREATE OR REPLACE FUNCTION process_check_in()
RETURNS TRIGGER AS $$
BEGIN
  -- Update member information
  UPDATE members
  SET
    -- Decrement remaining classes for class-based memberships
    remaining_classes = CASE 
      WHEN NOT NEW.is_extra 
        AND membership IN ('single_class', 'two_classes', 'ten_classes') 
      THEN remaining_classes - 1
      ELSE remaining_classes
    END,
    -- Increment extra check-ins counter
    extra_check_ins = CASE 
      WHEN NEW.is_extra 
      THEN extra_check_ins + 1
      ELSE extra_check_ins
    END,
    -- Update new member status
    is_new_member = false
  WHERE id = NEW.member_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Enhanced member search function
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
  v_normalized_name text;
BEGIN
  -- Normalize input name
  v_normalized_name := LOWER(TRIM(p_name));

  -- First try exact match with both name and email if provided
  IF p_email IS NOT NULL THEN
    RETURN QUERY
    SELECT 
      m.id,
      m.is_new_member,
      false::boolean
    FROM members m
    WHERE LOWER(TRIM(m.name)) = v_normalized_name
      AND LOWER(TRIM(m.email)) = LOWER(TRIM(p_email));
    
    IF FOUND THEN
      RETURN;
    END IF;
  END IF;

  -- Count exact name matches
  SELECT COUNT(*) INTO v_member_count
  FROM members
  WHERE LOWER(TRIM(name)) = v_normalized_name;

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
    WHERE LOWER(TRIM(m.name)) = v_normalized_name;
  ELSE
    -- No match - new member
    RETURN QUERY SELECT NULL::uuid, true::boolean, false::boolean;
  END IF;
END;
$$ LANGUAGE plpgsql;