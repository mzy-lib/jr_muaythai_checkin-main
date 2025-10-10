-- Fix member search function to properly handle duplicate names
BEGIN;

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
  v_normalized_email text;
BEGIN
  -- Input validation
  IF TRIM(p_name) = '' THEN
    RAISE EXCEPTION 'Name cannot be empty';
  END IF;

  -- Normalize inputs
  v_normalized_name := LOWER(TRIM(p_name));
  v_normalized_email := CASE WHEN p_email IS NOT NULL 
    THEN LOWER(TRIM(p_email)) 
    ELSE NULL 
  END;

  -- First try exact match with email if provided
  IF v_normalized_email IS NOT NULL THEN
    RETURN QUERY
    SELECT 
      m.id,
      m.is_new_member,
      false
    FROM members m
    WHERE LOWER(TRIM(m.name)) = v_normalized_name
      AND LOWER(TRIM(m.email)) = v_normalized_email;
    
    IF FOUND THEN
      RETURN;
    END IF;
  END IF;

  -- Try exact name match
  SELECT COUNT(*) INTO v_member_count
  FROM members m
  WHERE LOWER(TRIM(m.name)) = v_normalized_name;

  -- Handle exact name matches
  IF v_member_count > 1 THEN
    -- Multiple exact matches - require email
    RETURN QUERY SELECT NULL::uuid, false, true;
    RETURN;
  ELSIF v_member_count = 1 THEN
    -- Single exact match
    RETURN QUERY
    SELECT 
      m.id,
      m.is_new_member,
      false
    FROM members m
    WHERE LOWER(TRIM(m.name)) = v_normalized_name;
    RETURN;
  END IF;

  -- No exact matches found - treat as new member
  RETURN QUERY SELECT NULL::uuid, true, false;
END;
$$ LANGUAGE plpgsql;

COMMIT; 