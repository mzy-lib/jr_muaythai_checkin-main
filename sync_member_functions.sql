-- Drop existing functions
DROP FUNCTION IF EXISTS public.check_duplicate_name() CASCADE;
DROP FUNCTION IF EXISTS public.create_new_member(text, text, class_type) CASCADE;
DROP FUNCTION IF EXISTS public.register_new_member(text, text, class_type) CASCADE;
DROP FUNCTION IF EXISTS public.validate_member_name(text) CASCADE;
DROP FUNCTION IF EXISTS public.validate_member_name(text, text) CASCADE;

-- Recreate check_duplicate_name function
CREATE OR REPLACE FUNCTION public.check_duplicate_name()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
  existing_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO existing_count
  FROM members 
  WHERE LOWER(TRIM(name)) = LOWER(TRIM(NEW.name))
  AND id != NEW.id;

  IF existing_count > 0 AND NEW.email IS NULL THEN
    RAISE EXCEPTION 'Duplicate name found. Email is required for verification.';
  END IF;

  RETURN NEW;
END;
$function$;

-- Recreate create_new_member function
CREATE OR REPLACE FUNCTION public.create_new_member(p_name text, p_email text, p_class_type class_type)
RETURNS json
LANGUAGE plpgsql
AS $function$
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
$function$;

-- Recreate register_new_member function
CREATE OR REPLACE FUNCTION public.register_new_member(p_name text, p_email text, p_class_type class_type)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
  v_member_id uuid;
  v_check_in_id uuid;
  v_existing_member RECORD;
BEGIN
  -- Input validation
  IF NOT validate_member_name(p_name, p_email) THEN
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
$function$;

-- Recreate validate_member_name function with email parameter
CREATE OR REPLACE FUNCTION public.validate_member_name(p_name text, p_email text DEFAULT NULL::text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
BEGIN
  -- Basic validation
  IF TRIM(p_name) = '' THEN
    RAISE EXCEPTION '姓名不能为空。Name cannot be empty.'
      USING HINT = 'empty_name';
  END IF;

  -- Check for invalid characters
  IF p_name !~ '^[a-zA-Z0-9\u4e00-\u9fa5@._\-\s]+$' THEN
    RAISE EXCEPTION '姓名包含无效字符。Name contains invalid characters.'
      USING HINT = 'invalid_characters';
  END IF;

  -- For new member registration, email is required
  IF p_email IS NULL OR TRIM(p_email) = '' THEN
    RAISE EXCEPTION '邮箱是必填字段。Email is required.'
      USING HINT = 'email_required';
  END IF;

  RETURN true;
EXCEPTION
  WHEN OTHERS THEN
    RAISE;
END;
$function$;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION public.check_duplicate_name() TO postgres, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.create_new_member(text, text, class_type) TO postgres, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.register_new_member(text, text, class_type) TO postgres, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.validate_member_name(text) TO postgres, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.validate_member_name(text, text) TO postgres, anon, authenticated, service_role;

-- Create or replace the check_duplicate_name trigger
DROP TRIGGER IF EXISTS check_duplicate_name_trigger ON members;
CREATE TRIGGER check_duplicate_name_trigger
    BEFORE INSERT OR UPDATE ON members
    FOR EACH ROW
    EXECUTE FUNCTION check_duplicate_name(); 