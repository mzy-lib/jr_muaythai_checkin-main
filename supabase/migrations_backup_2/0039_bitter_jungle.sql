-- Drop existing function first
DROP FUNCTION IF EXISTS find_member_for_checkin(text, text);

-- Create new function with updated return type
CREATE OR REPLACE FUNCTION find_member_for_checkin(
  p_name text,
  p_email text DEFAULT NULL
)
RETURNS TABLE (
  member_id uuid,
  is_new boolean,
  needs_email boolean,
  member_name text
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
      false::boolean,
      m.name
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

  -- If multiple members found with same name, require email
  IF v_member_count > 1 THEN
    RETURN QUERY
    SELECT 
      NULL::uuid,
      false::boolean,
      true::boolean,
      NULL::text;
    RETURN;
  -- If exactly one member found, return that member
  ELSIF v_member_count = 1 THEN
    RETURN QUERY
    SELECT 
      m.id,
      m.is_new_member,
      false::boolean,
      m.name
    FROM members m
    WHERE LOWER(TRIM(m.name)) = v_normalized_name;
    RETURN;
  END IF;

  -- Try partial match if no exact match found
  RETURN QUERY
  SELECT 
    NULL::uuid,
    true::boolean,
    false::boolean,
    NULL::text;
END;
$$ LANGUAGE plpgsql;

-- Add comment to document function behavior
COMMENT ON FUNCTION find_member_for_checkin(text, text) IS 
'Finds a member for check-in by name and optional email.
Returns:
- member_id: UUID of found member or NULL
- is_new: true if no member found (new member)
- needs_email: true if multiple members found with same name
- member_name: name of found member or NULL';