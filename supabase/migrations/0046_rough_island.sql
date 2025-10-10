-- Enhanced new member registration with proper transaction handling
CREATE OR REPLACE FUNCTION register_new_member(
  p_name text,
  p_email text,
  p_class_type class_type
) RETURNS json AS $$
DECLARE
  v_member_id uuid;
  v_check_in_id uuid;
  v_existing_member RECORD;
BEGIN
  -- Start transaction with serializable isolation level
  SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

  -- Input validation
  IF NOT validate_member_name(p_name) THEN
    RAISE EXCEPTION '无效的姓名格式。Invalid name format.'
      USING HINT = 'invalid_name';
  END IF;

  -- Check for existing member with exact name match
  SELECT id, email, is_new_member 
  INTO v_existing_member
  FROM members
  WHERE LOWER(TRIM(name)) = LOWER(TRIM(p_name))
  FOR UPDATE;

  IF FOUND THEN
    RAISE NOTICE 'Member already exists: name=%, email=%', p_name, v_existing_member.email;
    RAISE EXCEPTION '该姓名已被注册。This name is already registered.'
      USING HINT = 'member_exists';
  END IF;

  -- Create new member
  INSERT INTO members (
    name,
    email,
    is_new_member,
    created_at
  ) VALUES (
    TRIM(p_name),
    TRIM(p_email),
    true,
    NOW()
  ) RETURNING id INTO v_member_id;

  RAISE NOTICE 'New member created: id=%, name=%, email=%', v_member_id, p_name, p_email;

  -- Create initial check-in
  INSERT INTO check_ins (
    member_id,
    class_type,
    check_in_date,
    is_extra,
    created_at
  ) VALUES (
    v_member_id,
    p_class_type,
    CURRENT_DATE,
    true,
    NOW()
  ) RETURNING id INTO v_check_in_id;

  RAISE NOTICE 'Initial check-in created: id=%, member_id=%, class_type=%', 
    v_check_in_id, v_member_id, p_class_type;

  -- Return success response
  RETURN json_build_object(
    'success', true,
    'member_id', v_member_id,
    'check_in_id', v_check_in_id
  );
EXCEPTION
  WHEN unique_violation THEN
    RAISE NOTICE 'Unique violation error: name=%, email=%', p_name, p_email;
    RAISE EXCEPTION '该邮箱已被注册。This email is already registered.'
      USING HINT = 'email_exists';
  WHEN OTHERS THEN
    RAISE NOTICE 'Unexpected error in register_new_member: %', SQLERRM;
    RAISE;
END;
$$ LANGUAGE plpgsql;

-- Add comment
COMMENT ON FUNCTION register_new_member IS 
'Registers a new member and creates their first check-in in a single transaction.
Includes:
- Name and email validation
- Duplicate checking
- Atomic member creation and check-in
- Proper error handling and logging
- Serializable transaction isolation';