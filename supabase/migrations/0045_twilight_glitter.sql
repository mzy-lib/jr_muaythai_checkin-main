-- Add test data for check-in system testing
BEGIN;

-- Clean up any existing test data
DELETE FROM check_ins WHERE member_id IN (
  SELECT id FROM members WHERE email LIKE '%test.checkin%'
);
DELETE FROM members WHERE email LIKE '%test.checkin%';

-- Add test members
INSERT INTO members (
  name,
  email,
  membership,
  remaining_classes,
  membership_expiry,
  is_new_member,
  created_at
) VALUES
  -- Monthly membership members
  ('测试会员A', 'member.a@test.checkin', 'single_daily_monthly', 0, 
   CURRENT_DATE + INTERVAL '30 days', false, NOW()),
   
  ('测试会员B', 'member.b@test.checkin', 'double_daily_monthly', 0,
   CURRENT_DATE + INTERVAL '30 days', false, NOW()),
   
  ('测试会员C', 'member.c@test.checkin', 'single_daily_monthly', 0,
   CURRENT_DATE - INTERVAL '5 days', false, NOW()),

  -- Class-based membership members  
  ('测试会员D', 'member.d@test.checkin', 'ten_classes', 5,
   NULL, false, NOW()),
   
  ('测试会员E', 'member.e@test.checkin', 'single_class', 0,
   NULL, false, NOW()),

  -- Duplicate name members
  ('王小明', 'wang.1@test.checkin', 'ten_classes', 3,
   NULL, false, NOW()),
   
  ('王小明', 'wang.2@test.checkin', 'single_daily_monthly', 0,
   CURRENT_DATE + INTERVAL '15 days', false, NOW()),

  -- New member
  ('新会员测试', 'new.member@test.checkin', NULL, 0,
   NULL, true, NOW());

COMMIT;