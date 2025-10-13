-- Restore class_type field and update related functions
BEGIN;

-- 1. Add back class_type column if not exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_name = 'check_ins' 
    AND column_name = 'class_type'
  ) THEN
    ALTER TABLE check_ins ADD COLUMN class_type class_type;
  END IF;
END $$;

-- 2. Create function to convert time_slot to class_type
CREATE OR REPLACE FUNCTION get_class_type_from_time_slot(p_time_slot text)
RETURNS class_type
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN CASE 
    WHEN p_time_slot = '09:00-10:30' THEN 'morning'::class_type
    WHEN p_time_slot = '17:00-18:30' THEN 'evening'::class_type
    ELSE 'morning'::class_type  -- Default to morning for private classes
  END;
END;
$$;

-- 3. Update register_new_member function
CREATE OR REPLACE FUNCTION register_new_member(
  p_name text,
  p_email text,
  p_time_slot text,
  p_is_private boolean DEFAULT false,
  p_trainer_id uuid DEFAULT null,
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

  -- Time slot validation
  IF p_time_slot IS NULL OR TRIM(p_time_slot) = '' THEN
    RAISE EXCEPTION '必须选择时段。Time slot is required.'
      USING HINT = 'time_slot_required';
  END IF;

  -- Basic time slot format validation
  IF p_time_slot !~ '^\d{2}:\d{2}-\d{2}:\d{2}$' THEN
    RAISE EXCEPTION '无效的时间段格式。Invalid time slot format.'
      USING HINT = 'invalid_time_slot_format';
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
  ELSE
    -- For group classes, validate time slot
    IF p_time_slot NOT IN ('09:00-10:30', '17:00-18:30') THEN
      RAISE EXCEPTION '无效的团课时段。Invalid group class time slot.'
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

  -- Create initial check-in
  INSERT INTO check_ins (
    member_id,
    check_in_date,
    is_extra,
    is_private,
    trainer_id,
    time_slot,
    is_1v2,
    created_at,
    class_type  -- Include class_type based on time_slot
  ) VALUES (
    v_member_id,
    CURRENT_DATE,
    true,
    p_is_private,
    p_trainer_id,
    p_time_slot,
    p_is_1v2,
    NOW(),
    get_class_type_from_time_slot(p_time_slot)  -- Set class_type based on time_slot
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

-- 4. Update check_in_validation trigger function
CREATE OR REPLACE FUNCTION check_in_validation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_existing_check_in RECORD;
  v_time_slot text;
BEGIN
  -- Check for duplicate check-in
  SELECT id, time_slot, is_private
  INTO v_existing_check_in
  FROM check_ins
  WHERE member_id = NEW.member_id
    AND check_in_date = NEW.check_in_date
    AND time_slot = NEW.time_slot
    AND is_private = NEW.is_private;

  IF FOUND THEN
    IF v_existing_check_in.is_private THEN
      RAISE EXCEPTION '今天已经签到过这个时段的私教课。Already checked in for this private class time slot today.'
        USING HINT = 'duplicate_checkin';
    ELSE
      RAISE EXCEPTION '今天已经签到过这个时段的课程。Already checked in for this time slot today.'
        USING HINT = 'duplicate_checkin';
    END IF;
  END IF;

  -- Validate time slot
  IF NOT validate_time_slot(NEW.time_slot, NEW.check_in_date, NEW.is_private) THEN
    RAISE EXCEPTION '无效的时间段。Invalid time slot.'
      USING HINT = 'invalid_time_slot';
  END IF;

  -- Set class_type based on time_slot
  NEW.class_type := get_class_type_from_time_slot(NEW.time_slot);

  RETURN NEW;
END;
$$;

-- 5. Update existing records
UPDATE check_ins
SET class_type = get_class_type_from_time_slot(time_slot)
WHERE class_type IS NULL;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION get_class_type_from_time_slot(text) TO public;
GRANT EXECUTE ON FUNCTION register_new_member(text, text, text, boolean, uuid, boolean) TO public;
GRANT EXECUTE ON FUNCTION check_in_validation() TO public;

COMMIT; 