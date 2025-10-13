-- Unify time_slot for both group and private classes
BEGIN;

-- 1. Create a function to convert class_type to time_slot
CREATE OR REPLACE FUNCTION convert_class_type_to_time_slot(p_class_type class_type)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN CASE 
    WHEN p_class_type = 'morning' THEN '09:00-10:30'
    WHEN p_class_type = 'evening' THEN '17:00-18:30'
    ELSE NULL
  END;
END;
$$;

-- 2. First check records that need to be updated
DO $$
DECLARE
  v_record RECORD;
BEGIN
  RAISE NOTICE '以下记录的time_slot为空 (Following records have null time_slot):';
  FOR v_record IN 
    SELECT id, member_id, class_type, is_private, check_in_date
    FROM check_ins 
    WHERE time_slot IS NULL
  LOOP
    RAISE NOTICE 'ID: %, Member: %, Type: %, Private: %, Date: %',
      v_record.id, v_record.member_id, v_record.class_type, v_record.is_private, v_record.check_in_date;
  END LOOP;
END;
$$;

-- 3. First handle the private class type record
UPDATE check_ins
SET time_slot = '09:00-10:30'  -- 设置一个默认的时间段
WHERE time_slot IS NULL AND class_type = 'private';

-- 4. Update remaining check_ins to set time_slot based on class_type
UPDATE check_ins
SET time_slot = convert_class_type_to_time_slot(class_type)
WHERE time_slot IS NULL;

-- 5. Verify no null time_slots remain
DO $$
DECLARE
  v_null_count integer;
BEGIN
  SELECT COUNT(*)
  INTO v_null_count
  FROM check_ins
  WHERE time_slot IS NULL;

  IF v_null_count > 0 THEN
    RAISE EXCEPTION '还有 % 条记录的time_slot为空。Still have % records with null time_slot.', v_null_count, v_null_count;
  END IF;
END;
$$;

-- 6. Now add NOT NULL constraint
ALTER TABLE check_ins
ALTER COLUMN time_slot SET NOT NULL;

-- 7. Update register_new_member function to use time_slot
CREATE OR REPLACE FUNCTION register_new_member(
  p_name text,
  p_email text,
  p_class_type class_type,  -- Keep for backward compatibility
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
  v_time_slot text;
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

  -- Determine time slot
  IF p_is_private THEN
    -- Private class validation
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

    -- Only validate time slot format
    IF p_time_slot !~ '^\d{2}:\d{2}-\d{2}:\d{2}$' THEN
      RAISE EXCEPTION '无效的时间段格式。Invalid time slot format.'
        USING HINT = 'invalid_time_slot_format';
    END IF;
    
    v_time_slot := p_time_slot;
  ELSE
    -- Group class
    v_time_slot := convert_class_type_to_time_slot(p_class_type);
    
    -- Ensure we got a valid time slot
    IF v_time_slot IS NULL THEN
      RAISE EXCEPTION '无效的团课类型。Invalid group class type.'
        USING HINT = 'invalid_class_type';
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
    class_type,  -- Keep for now, will be removed in future migration
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
    v_time_slot,
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

-- 8. Create a function to validate any time slot (both group and private)
CREATE OR REPLACE FUNCTION validate_time_slot(
  p_time_slot text,
  p_check_in_date date,
  p_is_private boolean
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Basic format validation
  IF p_time_slot !~ '^\d{2}:\d{2}-\d{2}:\d{2}$' THEN
    RETURN false;
  END IF;

  -- For group classes
  IF NOT p_is_private THEN
    RETURN p_time_slot IN ('09:00-10:30', '17:00-18:30');
  END IF;

  -- For private classes, trust the frontend validation
  RETURN true;
END;
$$;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION convert_class_type_to_time_slot(class_type) TO public;
GRANT EXECUTE ON FUNCTION validate_time_slot(text, date, boolean) TO public;
GRANT EXECUTE ON FUNCTION register_new_member(text, text, class_type, boolean, uuid, text, boolean) TO public;

COMMIT; 