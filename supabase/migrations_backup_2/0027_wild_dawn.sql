-- Enhanced member search for check-in with duplicate name handling
CREATE OR REPLACE FUNCTION find_member_for_checkin(
  p_name text,
  p_email text DEFAULT NULL
)
RETURNS uuid AS $$
DECLARE
  v_member_id uuid;
  v_member_count int;
BEGIN
  -- First try exact match with both name and email if provided
  IF p_email IS NOT NULL THEN
    SELECT id INTO v_member_id
    FROM members
    WHERE LOWER(TRIM(name)) = LOWER(TRIM(p_name))
      AND LOWER(TRIM(email)) = LOWER(TRIM(p_email));
    
    IF FOUND THEN
      RETURN v_member_id;
    END IF;
  END IF;

  -- Count members with matching name
  SELECT COUNT(*) INTO v_member_count
  FROM members
  WHERE LOWER(TRIM(name)) = LOWER(TRIM(p_name));

  -- If multiple members found with same name, require email
  IF v_member_count > 1 THEN
    RAISE EXCEPTION '存在多个同名会员，请提供邮箱以验证身份。Multiple members found with the same name, please provide email for verification.'
      USING HINT = 'duplicate_name';
  -- If exactly one member found, return that ID
  ELSIF v_member_count = 1 THEN
    SELECT id INTO v_member_id
    FROM members
    WHERE LOWER(TRIM(name)) = LOWER(TRIM(p_name));
    RETURN v_member_id;
  END IF;

  -- No member found
  RAISE EXCEPTION '未找到会员，请检查姓名或前往新会员签到。Member not found, please check the name or proceed to new member check-in.'
    USING HINT = 'member_not_found';
END;
$$ LANGUAGE plpgsql;

-- Update process_check_in to use the new function
CREATE OR REPLACE FUNCTION process_check_in()
RETURNS TRIGGER AS $$
DECLARE
  v_membership membership_type;
  v_remaining_classes int;
  v_membership_expiry timestamptz;
  v_daily_check_ins int;
  v_same_class_check_ins int;
BEGIN
  -- Get member details with lock
  SELECT 
    membership,
    remaining_classes,
    membership_expiry
  INTO
    v_membership,
    v_remaining_classes,
    v_membership_expiry
  FROM members
  WHERE id = NEW.member_id
  FOR UPDATE;

  -- Check for same class type check-ins today
  SELECT COUNT(*)
  INTO v_same_class_check_ins
  FROM check_ins
  WHERE member_id = NEW.member_id
    AND check_in_date = CURRENT_DATE
    AND class_type = NEW.class_type;

  IF v_same_class_check_ins > 0 THEN
    RAISE EXCEPTION '您今天已在该时段签到。请返回首页选择其他时段。You have already checked in for this class type today. Please return home and choose another class time.'
      USING HINT = 'duplicate_class';
  END IF;

  -- Count total daily check-ins
  SELECT COUNT(*)
  INTO v_daily_check_ins
  FROM check_ins
  WHERE member_id = NEW.member_id
    AND check_in_date = CURRENT_DATE
    AND is_extra = false;

  -- Determine if this is an extra check-in
  NEW.is_extra := CASE
    WHEN v_membership IS NULL THEN true
    WHEN v_membership IN ('single_daily_monthly', 'double_daily_monthly') THEN
      CASE
        WHEN v_membership_expiry < CURRENT_DATE THEN true
        WHEN v_membership = 'single_daily_monthly' AND v_daily_check_ins >= 1 THEN true
        WHEN v_membership = 'double_daily_monthly' AND v_daily_check_ins >= 2 THEN true
        ELSE false
      END
    WHEN v_membership IN ('single_class', 'two_classes', 'ten_classes') THEN
      v_remaining_classes <= 0
    ELSE true
  END;

  -- Update member information
  IF NOT NEW.is_extra THEN
    IF v_membership IN ('single_class', 'two_classes', 'ten_classes') THEN
      UPDATE members
      SET remaining_classes = remaining_classes - 1
      WHERE id = NEW.member_id;
    END IF;
  ELSE
    UPDATE members
    SET extra_check_ins = extra_check_ins + 1
    WHERE id = NEW.member_id;
  END IF;

  -- Update new member status
  UPDATE members
  SET is_new_member = false
  WHERE id = NEW.member_id
    AND is_new_member = true;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;