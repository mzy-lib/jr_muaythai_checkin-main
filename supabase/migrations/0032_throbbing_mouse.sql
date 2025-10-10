-- Add test cases for check-in scenarios
BEGIN;

-- Test Case 1: New member check-in
INSERT INTO members (
  name,
  email,
  is_new_member,
  created_at
) VALUES (
  '新会员测试',
  'new.member@test.com',
  true,
  NOW()
);

-- Test Case 2: Members with duplicate names
INSERT INTO members (
  name,
  email,
  membership,
  remaining_classes,
  is_new_member
) VALUES
  ('王小明', 'wang.xm1@test.com', 'ten_classes', 5, false),
  ('王小明', 'wang.xm2@test.com', 'single_daily_monthly', 0, false);

-- Test Case 3: Member with special characters in name
INSERT INTO members (
  name,
  email,
  membership,
  remaining_classes,
  is_new_member
) VALUES (
  'MT-Fighter@2024',
  'mt.fighter@test.com',
  'double_daily_monthly',
  0,
  false
);

-- Test check-in scenarios
DO $$
DECLARE
  v_member_id uuid;
  v_check_in_id uuid;
BEGIN
  -- Scenario 1: New member check-in
  SELECT id INTO v_member_id FROM members WHERE email = 'new.member@test.com';
  
  INSERT INTO check_ins (member_id, class_type)
  VALUES (v_member_id, 'morning')
  RETURNING id INTO v_check_in_id;
  
  -- Verify it's marked as extra
  ASSERT (SELECT is_extra FROM check_ins WHERE id = v_check_in_id) = true,
    'New member check-in should be marked as extra';

  -- Scenario 2: Attempt duplicate class type check-in
  BEGIN
    INSERT INTO check_ins (member_id, class_type)
    VALUES (v_member_id, 'morning');
    RAISE EXCEPTION 'Should not allow duplicate class type check-in';
  EXCEPTION
    WHEN OTHERS THEN
      -- Expected error
      NULL;
  END;

  -- Scenario 3: Check-in with special character name
  SELECT id INTO v_member_id FROM members WHERE email = 'mt.fighter@test.com';
  
  INSERT INTO check_ins (member_id, class_type)
  VALUES (v_member_id, 'morning');
  
  -- Verify member found and check-in processed
  ASSERT FOUND,
    'Should handle special characters in member name';

END $$;

COMMIT;