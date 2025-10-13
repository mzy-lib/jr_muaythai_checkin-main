/*
  # Add test data

  1. New Data
    - Add test members with various membership types
    - Add check-in records for test members
  
  2. Test Scenarios
    - Members with different membership types
    - Mix of regular and extra check-ins
    - Various membership expiry dates
*/

-- Wrap everything in a transaction
BEGIN;

-- Create test members
INSERT INTO members (
  name,
  email,
  membership,
  remaining_classes,
  membership_expiry,
  is_new_member,
  created_at
) VALUES
  -- Ten-class package member
  ('张三', 'zhang.san@example.com', 'ten_classes', 7, NULL, false, NOW()),
  
  -- Single daily monthly member (active)
  ('李四', 'li.si@example.com', 'single_daily_monthly', 0, NOW() + INTERVAL '15 days', false, NOW()),
  
  -- Double daily monthly member (active)
  ('王五', 'wang.wu@example.com', 'double_daily_monthly', 0, NOW() + INTERVAL '30 days', false, NOW()),
  
  -- Single class member
  ('赵六', 'zhao.liu@example.com', 'single_class', 1, NULL, false, NOW()),
  
  -- Two classes member
  ('孙七', 'sun.qi@example.com', 'two_classes', 2, NULL, false, NOW()),
  
  -- Expired monthly member
  ('周八', 'zhou.ba@example.com', 'single_daily_monthly', 0, NOW() - INTERVAL '5 days', false, NOW()),
  
  -- New member without membership
  ('吴九', 'wu.jiu@example.com', NULL, 0, NULL, true, NOW());

-- Add check-in records for the past week
INSERT INTO check_ins (
  member_id,
  class_type,
  check_in_date,
  created_at,
  is_extra
)
SELECT 
  m.id,
  CASE WHEN EXTRACT(DOW FROM d.date) % 2 = 0 THEN 'morning'::class_type ELSE 'evening'::class_type END,
  d.date,
  d.date + TIME '09:00:00',
  CASE 
    WHEN m.membership = 'single_daily_monthly' AND EXISTS (
      SELECT 1 FROM check_ins ci 
      WHERE ci.member_id = m.id 
      AND ci.check_in_date = d.date
    ) THEN true
    ELSE false
  END
FROM members m
CROSS JOIN (
  SELECT generate_series(
    NOW() - INTERVAL '7 days',
    NOW(),
    INTERVAL '1 day'
  )::date AS date
) d
WHERE m.name IN ('张三', '李四', '王五')
AND EXTRACT(DOW FROM d.date) BETWEEN 1 AND 6; -- Only weekdays

COMMIT;