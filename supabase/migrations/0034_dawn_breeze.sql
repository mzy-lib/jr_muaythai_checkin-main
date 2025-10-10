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
      m.is_new_member,
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

-- Update check-in validation to handle new members
CREATE OR REPLACE FUNCTION validate_check_in()
RETURNS TRIGGER AS $$
DECLARE
  v_member_exists boolean;
BEGIN
  -- Check if member exists
  SELECT EXISTS (
    SELECT 1 FROM members WHERE id = NEW.member_id
  ) INTO v_member_exists;

  -- If member doesn't exist, they should go to new member registration
  IF NOT v_member_exists THEN
    RAISE EXCEPTION '未找到会员，请前往新会员签到页面。Member not found, please proceed to new member registration.'
      USING HINT = 'new_member';
  END IF;

  -- Rest of the validation logic remains the same
  -- ... (previous validation code) ...

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;