-- Clean up and set up test data
BEGIN;

-- Clean up existing test data
DELETE FROM check_ins WHERE member_id IN (
  SELECT id FROM members WHERE email LIKE '%test.mt@example.com'
);
DELETE FROM members WHERE email LIKE '%test.mt@example.com';

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
  -- Monthly memberships
  ('张三', 'zhang.san.test.mt@example.com', 'single_daily_monthly', 0, 
   CURRENT_DATE + INTERVAL '30 days', false, NOW()),
  ('李四', 'li.si.test.mt@example.com', 'double_daily_monthly', 0,
   CURRENT_DATE + INTERVAL '15 days', false, NOW()),
  ('王五', 'wang.wu.test.mt@example.com', 'single_daily_monthly', 0,
   CURRENT_DATE - INTERVAL '5 days', false, NOW()),

  -- Class-based memberships
  ('赵六', 'zhao.liu.test.mt@example.com', 'ten_classes', 5, NULL, false, NOW()),
  ('孙七', 'sun.qi.test.mt@example.com', 'two_classes', 2, NULL, false, NOW()),
  ('周八', 'zhou.ba.test.mt@example.com', 'single_class', 0, NULL, false, NOW()),

  -- Duplicate names
  ('王小明', 'wang.xm1.test.mt@example.com', 'ten_classes', 3, NULL, false, NOW()),
  ('王小明', 'wang.xm2.test.mt@example.com', 'single_daily_monthly', 0,
   CURRENT_DATE + INTERVAL '15 days', false, NOW()),

  -- New member
  ('新学员', 'new.member.test.mt@example.com', NULL, 0, NULL, true, NOW());

-- Add initial check-ins for testing duplicate scenarios
INSERT INTO check_ins (member_id, class_type, check_in_date, is_extra)
SELECT id, 'morning', CURRENT_DATE, false
FROM members 
WHERE email = 'zhang.san.test.mt@example.com';

COMMIT;