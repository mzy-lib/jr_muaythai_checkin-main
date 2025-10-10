-- Enhanced member search with improved name matching
CREATE OR REPLACE FUNCTION find_member_for_checkin(
  p_name text,
  p_email text DEFAULT NULL
)
RETURNS TABLE (
  member_id uuid,
  is_new boolean,
  needs_email boolean,
  member_name text,
  member_email text,
  membership_type text
) AS $$
DECLARE
  v_member_count int;
  v_normalized_name text;
BEGIN
  -- Enhanced name normalization
  v_normalized_name := regexp_replace(
    LOWER(TRIM(p_name)),
    '[\s_\-@\.]+',  -- Remove spaces, underscores, hyphens, @ and dots
    '',
    'g'
  );

  -- First try exact match with both name and email if provided
  IF p_email IS NOT NULL THEN
    RETURN QUERY
    SELECT 
      m.id,
      m.is_new_member,
      false::boolean,
      m.name,
      m.email,
      m.membership::text
    FROM members m
    WHERE regexp_replace(LOWER(TRIM(m.name)), '[\s_\-@\.]+', '', 'g') = v_normalized_name
      AND LOWER(TRIM(m.email)) = LOWER(TRIM(p_email));
    
    IF FOUND THEN
      RETURN;
    END IF;
  END IF;

  -- Count exact name matches
  SELECT COUNT(*) INTO v_member_count
  FROM members m
  WHERE regexp_replace(LOWER(TRIM(m.name)), '[\s_\-@\.]+', '', 'g') = v_normalized_name;

  -- If multiple members found with same name, return their details
  IF v_member_count > 1 THEN
    RETURN QUERY
    SELECT 
      NULL::uuid,
      false::boolean,
      true::boolean,
      m.name,
      m.email,
      m.membership::text
    FROM members m
    WHERE regexp_replace(LOWER(TRIM(m.name)), '[\s_\-@\.]+', '', 'g') = v_normalized_name
    ORDER BY m.created_at DESC;
    RETURN;
  -- If exactly one member found, return that member
  ELSIF v_member_count = 1 THEN
    RETURN QUERY
    SELECT 
      m.id,
      m.is_new_member,
      false::boolean,
      m.name,
      m.email,
      m.membership::text
    FROM members m
    WHERE regexp_replace(LOWER(TRIM(m.name)), '[\s_\-@\.]+', '', 'g') = v_normalized_name;
    RETURN;
  END IF;

  -- No member found - indicate new member
  RETURN QUERY
  SELECT 
    NULL::uuid,
    true::boolean,
    false::boolean,
    NULL::text,
    NULL::text,
    NULL::text;
END;
$$ LANGUAGE plpgsql;

-- Enhanced check-in validation
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

  -- Check for duplicate class type with improved time window
  SELECT COUNT(*)
  INTO v_same_class_check_ins
  FROM check_ins
  WHERE member_id = NEW.member_id
    AND check_in_date = CURRENT_DATE
    AND class_type = NEW.class_type
    AND created_at >= CURRENT_TIMESTAMP - INTERVAL '1 hour';

  IF v_same_class_check_ins > 0 THEN
    RAISE EXCEPTION '您最近已在该时段签到。请稍后再试或选择其他时段。You have recently checked in for this class. Please try again later or choose another class time.'
      USING HINT = 'duplicate_class';
  END IF;

  -- Enhanced membership validation
  CASE
    -- New members
    WHEN v_is_new_member THEN
      NEW.is_extra := true;
      
    -- Monthly memberships
    WHEN v_membership IN ('single_daily_monthly', 'double_daily_monthly') THEN
      IF v_membership_expiry < CURRENT_DATE THEN
        NEW.is_extra := true;
      ELSE
        -- Count valid check-ins for today
        SELECT COUNT(*)
        INTO v_daily_check_ins
        FROM check_ins
        WHERE member_id = NEW.member_id
          AND check_in_date = CURRENT_DATE
          AND is_extra = false
          AND created_at >= CURRENT_DATE;

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

    -- No membership or unknown type
    ELSE
      NEW.is_extra := true;
  END CASE;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add comments to document the improvements
COMMENT ON FUNCTION find_member_for_checkin(text, text) IS 
'Enhanced member search with improved name normalization and matching.
Returns additional member details for better duplicate handling.';

COMMENT ON FUNCTION validate_check_in() IS 
'Enhanced check-in validation with improved time window checks
and more accurate membership status validation.';