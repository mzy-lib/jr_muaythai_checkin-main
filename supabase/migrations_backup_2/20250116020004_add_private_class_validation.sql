-- Add validation for private class check-ins
BEGIN;

-- Create function to validate private class time slot
CREATE OR REPLACE FUNCTION validate_private_time_slot(p_time_slot text, p_check_in_date date)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_day_of_week integer;
BEGIN
  -- Get day of week (1-7, where 1 is Monday)
  v_day_of_week := EXTRACT(DOW FROM p_check_in_date);
  IF v_day_of_week = 0 THEN
    v_day_of_week := 7;
  END IF;

  -- Validate time slot format (HH:MM-HH:MM)
  IF p_time_slot !~ '^\d{2}:\d{2}-\d{2}:\d{2}$' THEN
    RETURN false;
  END IF;

  -- For weekdays (Monday to Friday)
  IF v_day_of_week BETWEEN 1 AND 5 THEN
    RETURN p_time_slot IN (
      '07:00-08:00', '08:00-09:00', '10:30-11:30',
      '14:00-15:00', '15:00-16:00', '16:00-17:00',
      '18:30-19:30'
    );
  -- For Saturday
  ELSIF v_day_of_week = 6 THEN
    RETURN p_time_slot IN (
      '07:00-08:00', '08:00-09:00',
      '14:00-15:00', '15:00-16:00', '16:00-17:00',
      '18:30-19:30'
    );
  END IF;

  RETURN false;
END;
$$;

-- Update register_new_member function with private class validation
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
  v_trainer_exists boolean;
BEGIN
  -- Input validation
  IF NOT validate_member_name(p_name) THEN
    RAISE EXCEPTION '无效的姓名格式。Invalid name format.'
      USING HINT = 'invalid_name';
  END IF;

  -- Email validation
  IF p_email IS NULL OR TRIM(p_email) = '' THEN
    RAISE EXCEPTION '邮箱是必填字段。Email is required.'
      USING HINT = 'email_required';
  END IF;

  -- Private class validation
  IF p_is_private THEN
    -- Validate trainer
    IF p_trainer_id IS NULL THEN
      RAISE EXCEPTION '私教课程必须选择教练。Trainer is required for private class.'
        USING HINT = 'trainer_required';
    END IF;

    -- Check if trainer exists
    SELECT EXISTS (
      SELECT 1 FROM trainers WHERE id = p_trainer_id
    ) INTO v_trainer_exists;

    IF NOT v_trainer_exists THEN
      RAISE EXCEPTION '教练不存在。Trainer does not exist.'
        USING HINT = 'invalid_trainer';
    END IF;

    -- Validate time slot
    IF p_time_slot IS NULL OR TRIM(p_time_slot) = '' THEN
      RAISE EXCEPTION '私教课程必须选择时段。Time slot is required for private class.'
        USING HINT = 'time_slot_required';
    END IF;

    -- Validate time slot format and value
    IF NOT validate_private_time_slot(p_time_slot, CURRENT_DATE) THEN
      RAISE EXCEPTION '无效的私教课时段。Invalid private class time slot.'
        USING HINT = 'invalid_time_slot';
    END IF;
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
GRANT EXECUTE ON FUNCTION validate_private_time_slot(text, date) TO public;
GRANT EXECUTE ON FUNCTION register_new_member(text, text, class_type, boolean, uuid, text, boolean) TO public;

COMMIT; 