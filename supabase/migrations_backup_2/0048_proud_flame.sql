-- Enhanced member search with better exact match handling
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
  v_exact_match_id uuid;
BEGIN
  -- Normalize input name
  v_normalized_name := LOWER(TRIM(p_name));

  -- First try exact match with both name and email if provided
  IF p_email IS NOT NULL THEN
    SELECT id INTO v_exact_match_id
    FROM members
    WHERE LOWER(TRIM(name)) = v_normalized_name
      AND LOWER(TRIM(email)) = LOWER(TRIM(p_email));
    
    IF FOUND THEN
      RETURN QUERY SELECT v_exact_match_id, false, false;
      RETURN;
    END IF;
  END IF;

  -- Try exact name match
  SELECT COUNT(*) INTO v_member_count
  FROM members
  WHERE LOWER(TRIM(name)) = v_normalized_name;

  -- If exactly one member found with exact name match
  IF v_member_count = 1 THEN
    SELECT id INTO v_exact_match_id
    FROM members
    WHERE LOWER(TRIM(name)) = v_normalized_name;
    
    RETURN QUERY SELECT v_exact_match_id, false, false;
    RETURN;
  -- If multiple members found with same name
  ELSIF v_member_count > 1 THEN
    RETURN QUERY SELECT NULL::uuid, false, true;
    RETURN;
  END IF;

  -- No match found - new member
  RETURN QUERY SELECT NULL::uuid, true, false;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION find_member_for_checkin IS 
'Enhanced member search that prioritizes exact matches and handles duplicates properly.
Returns:
- member_id: UUID of found member or NULL
- is_new: true if no member found
- needs_email: true if multiple members with same name exist';