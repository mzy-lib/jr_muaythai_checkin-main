-- Enhanced member search with new member redirection
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
      false::boolean, -- Never treat email-verified members as new
      false::boolean
    FROM members m
    WHERE LOWER(TRIM(m.name)) = v_normalized_name
      AND LOWER(TRIM(m.email)) = LOWER(TRIM(p_email));
    
    IF FOUND THEN
      RETURN;
    END IF;
  END IF;

  -- Count members with matching normalized name
  SELECT COUNT(*) INTO v_member_count
  FROM members
  WHERE LOWER(TRIM(name)) = v_normalized_name;

  -- If multiple members found with same name, require email
  IF v_member_count > 1 THEN
    RETURN QUERY
    SELECT 
      NULL::uuid,
      false::boolean,
      true::boolean;
    RETURN;
  -- If exactly one member found, return that member
  ELSIF v_member_count = 1 THEN
    RETURN QUERY
    SELECT 
      m.id,
      false::boolean, -- Existing members are never new
      false::boolean
    FROM members m
    WHERE LOWER(TRIM(m.name)) = v_normalized_name;
    RETURN;
  END IF;

  -- No member found - indicate new member
  RETURN QUERY
  SELECT 
    NULL::uuid,
    true::boolean,
    false::boolean;
END;
$$ LANGUAGE plpgsql;