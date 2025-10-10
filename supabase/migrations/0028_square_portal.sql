-- Enhanced member search with case-insensitive and whitespace-aware comparison
CREATE OR REPLACE FUNCTION find_member_for_checkin(
  p_name text,
  p_email text DEFAULT NULL
)
RETURNS uuid AS $$
DECLARE
  v_member_id uuid;
  v_member_count int;
  v_normalized_name text;
BEGIN
  -- Normalize input name: trim whitespace and convert to lowercase
  v_normalized_name := LOWER(TRIM(p_name));

  -- First try exact match with both name and email if provided
  IF p_email IS NOT NULL THEN
    SELECT id INTO v_member_id
    FROM members
    WHERE LOWER(TRIM(name)) = v_normalized_name
      AND LOWER(TRIM(email)) = LOWER(TRIM(p_email));
    
    IF FOUND THEN
      RETURN v_member_id;
    END IF;
  END IF;

  -- Count members with matching normalized name
  SELECT COUNT(*) INTO v_member_count
  FROM members
  WHERE LOWER(TRIM(name)) = v_normalized_name;

  -- If multiple members found with same name, require email
  IF v_member_count > 1 THEN
    RAISE EXCEPTION '存在多个同名会员，请提供邮箱以验证身份。Multiple members found with the same name, please provide email for verification.'
      USING HINT = 'duplicate_name';
  -- If exactly one member found, return that ID
  ELSIF v_member_count = 1 THEN
    SELECT id INTO v_member_id
    FROM members
    WHERE LOWER(TRIM(name)) = v_normalized_name;
    RETURN v_member_id;
  END IF;

  -- Try partial match if no exact match found
  SELECT COUNT(*) INTO v_member_count
  FROM members
  WHERE LOWER(TRIM(name)) LIKE '%' || v_normalized_name || '%';

  IF v_member_count = 1 THEN
    -- Single partial match found
    SELECT id INTO v_member_id
    FROM members
    WHERE LOWER(TRIM(name)) LIKE '%' || v_normalized_name || '%';
    RETURN v_member_id;
  ELSIF v_member_count > 1 THEN
    -- Multiple partial matches found
    RAISE EXCEPTION '找到多个相似名字的会员，请提供完整姓名或邮箱。Multiple members found with similar names, please provide full name or email.'
      USING HINT = 'multiple_matches';
  END IF;

  -- No member found
  RAISE EXCEPTION '未找到会员，请检查姓名或前往新会员签到。Member not found, please check the name or proceed to new member check-in.'
    USING HINT = 'member_not_found';
END;
$$ LANGUAGE plpgsql;