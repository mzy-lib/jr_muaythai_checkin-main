-- Clean up ALL test data thoroughly
BEGIN;

-- First clean up check-ins
DELETE FROM check_ins 
WHERE member_id IN (
  SELECT id FROM members 
  WHERE email LIKE '%test%'
  OR email LIKE '%example%'
);

-- Then clean up members
DELETE FROM members 
WHERE email LIKE '%test%'
OR email LIKE '%example%';

-- Add fresh test data with clear patterns
INSERT INTO members (
  name,
  email,
  membership,
  remaining_classes,
  membership_expiry,
  is_new_member,
  created_at
) VALUES
  -- Single member named 张三 (no duplicates)
  ('张三', 'zhangsan.test@mt.example.com', 'single_daily_monthly', 0, 
   CURRENT_DATE + INTERVAL '30 days', false, NOW()),

  -- Duplicate name test case
  ('王小明', 'wang.xm1@mt.example.com', 'ten_classes', 3,
   NULL, false, NOW()),
  ('王小明', 'wang.xm2@mt.example.com', 'single_daily_monthly', 0,
   CURRENT_DATE + INTERVAL '15 days', false, NOW());

COMMIT;