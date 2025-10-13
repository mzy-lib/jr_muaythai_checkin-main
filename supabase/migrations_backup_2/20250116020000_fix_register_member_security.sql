-- Fix security settings for register_new_member function
BEGIN;

-- Drop existing function if exists
DROP FUNCTION IF EXISTS register_new_member(text, text, class_type);

-- Create the function with proper security settings
CREATE OR REPLACE FUNCTION register_new_member(
  p_name text,
  p_email text,
  p_class_type class_type,
  p_is_private boolean DEFAULT false,
  p_trainer_id uuid DEFAULT null,
  p_time_slot text DEFAULT null,
  p_is_1v2 boolean DEFAULT false
) RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_member_id uuid;
  v_check_in_id uuid;
  v_existing_member RECORD;
BEGIN
  -- Input validation
  IF NOT validate_member_name(p_name) THEN
    RAISE EXCEPTION '无效的姓名格式。Invalid name format.'
      USING HINT = 'invalid_name';
  END IF;

  -- Lock the members table for the specific name to prevent concurrent registrations
  PERFORM 1 
  FROM members 
  WHERE LOWER(TRIM(name)) = LOWER(TRIM(p_name))
  FOR UPDATE SKIP LOCKED;

  -- Check if member exists after acquiring lock
  SELECT id, email, is_new_member 
  INTO v_existing_member
  FROM members
  WHERE LOWER(TRIM(name)) = LOWER(TRIM(p_name));

  IF FOUND THEN
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

  -- Create initial check-in with private class fields
  INSERT INTO check_ins (
    member_id,
    class_type,
    check_in_date,
    is_extra,
    is_private,
    trainer_id,
    time_slot,
    is_1v2,
    created_at
  ) VALUES (
    v_member_id,
    p_class_type,
    CURRENT_DATE,
    true,
    p_is_private,
    p_trainer_id,
    p_time_slot,
    p_is_1v2,
    NOW()
  ) RETURNING id INTO v_check_in_id;

  RETURN json_build_object(
    'success', true,
    'member_id', v_member_id,
    'check_in_id', v_check_in_id
  );

EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION '该邮箱已被注册。This email is already registered.'
      USING HINT = 'email_exists';
  WHEN OTHERS THEN
    RAISE EXCEPTION '%', SQLERRM;
END;
$$;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION register_new_member(text, text, class_type, boolean, uuid, text, boolean) TO public;
GRANT EXECUTE ON FUNCTION validate_member_name(text, text) TO public;

COMMIT; 