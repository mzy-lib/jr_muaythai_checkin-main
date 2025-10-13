-- Create a function to handle new member registration in a transaction
CREATE OR REPLACE FUNCTION create_new_member(
  p_name text,
  p_email text,
  p_class_type class_type
) RETURNS json AS $$
DECLARE
  v_member_id uuid;
  v_check_in_id uuid;
BEGIN
  -- Start transaction
  BEGIN
    -- Check for existing member with same name
    IF EXISTS (
      SELECT 1 FROM members 
      WHERE LOWER(TRIM(name)) = LOWER(TRIM(p_name))
    ) THEN
      RAISE EXCEPTION 'Member already exists'
        USING HINT = 'member_exists';
    END IF;

    -- Create new member
    INSERT INTO members (
      name,
      email,
      is_new_member
    ) VALUES (
      TRIM(p_name),
      TRIM(p_email),
      true
    ) RETURNING id INTO v_member_id;

    -- Create initial check-in
    INSERT INTO check_ins (
      member_id,
      class_type,
      is_extra
    ) VALUES (
      v_member_id,
      p_class_type,
      true
    ) RETURNING id INTO v_check_in_id;

    -- Return success response
    RETURN json_build_object(
      'success', true,
      'member_id', v_member_id,
      'check_in_id', v_check_in_id
    );
  EXCEPTION
    WHEN OTHERS THEN
      -- Rollback will happen automatically
      RAISE;
  END;
END;
$$ LANGUAGE plpgsql;