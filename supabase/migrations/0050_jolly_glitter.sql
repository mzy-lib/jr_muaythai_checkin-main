-- Fix test data and enhance email matching
BEGIN;

-- Clean up existing test data
DELETE FROM check_ins 
WHERE member_id IN (
  SELECT id FROM members 
  WHERE email LIKE '%test%'
  OR email LIKE '%example%'
  OR email LIKE '%mt.example%'
);

DELETE FROM members 
WHERE email LIKE '%test%'
OR email LIKE '%example%'
OR email LIKE '%mt.example%';

-- Add fresh test data with consistent email format
INSERT INTO members (
  name,
  email,
  membership,
  remaining_classes,
  membership_expiry,
  is_new_member,
  created_at
) VALUES
  -- Single member named 张三
  ('张三', 'zhangsan@mt.example.com', 'single_daily_monthly', 0, 
   CURRENT_DATE + INTERVAL '30 days', false, NOW()),

  -- Duplicate name test case - consistent email format
  ('王小明', 'wang.xm1@mt.example.com', 'ten_classes', 3,
   NULL, false, NOW()),
  ('王小明', 'wang.xm2@mt.example.com', 'single_daily_monthly', 0,
   CURRENT_DATE + INTERVAL '15 days', false, NOW());

-- Update member search function to handle email matching more robustly
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
  v_normalized_email text;
BEGIN
  -- Normalize inputs
  v_normalized_name := LOWER(TRIM(p_name));
  v_normalized_email := LOWER(TRIM(p_email));

  -- First try exact match with both name and email if provided
  IF v_normalized_email IS NOT NULL THEN
    RETURN QUERY
    SELECT 
      m.id,
      false,
      false
    FROM members m
    WHERE LOWER(TRIM(m.name)) = v_normalized_name
      AND LOWER(TRIM(m.email)) = v_normalized_email;
    
    IF FOUND THEN
      RETURN;
    END IF;
  END IF;

  -- Count exact name matches
  SELECT COUNT(*) INTO v_member_count
  FROM members
  WHERE LOWER(TRIM(name)) = v_normalized_name;

  -- Handle results
  IF v_member_count > 1 THEN
    -- Multiple matches - require email
    RETURN QUERY SELECT NULL::uuid, false, true;
  ELSIF v_member_count = 1 THEN
    -- Single match
    RETURN QUERY
    SELECT 
      m.id,
      false,
      false
    FROM members m
    WHERE LOWER(TRIM(m.name)) = v_normalized_name;
  ELSE
    -- No match - new member
    RETURN QUERY SELECT NULL::uuid, true, false;
  END IF;
END;
$$ LANGUAGE plpgsql;

COMMIT;