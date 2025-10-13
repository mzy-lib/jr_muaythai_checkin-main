/*
  # Add test members data

  1. New Members
    - Various membership types
    - Different expiry scenarios
    - Special name formats
    - Mixed language names
  
  2. Test Scenarios
    - Active monthly memberships
    - Expired memberships
    - Class-based packages
    - New members without memberships
*/

BEGIN;

-- Add test members with different scenarios
INSERT INTO members (
  name,
  email,
  membership,
  remaining_classes,
  membership_expiry,
  is_new_member,
  created_at
) VALUES
  -- Active single daily monthly member
  ('泰拳小子', 'thai.kid@test.com', 'single_daily_monthly', 0, 
   CURRENT_DATE + INTERVAL '30 days', false, NOW()),

  -- Active double daily monthly member
  ('Boxing Queen', 'boxing.queen@test.com', 'double_daily_monthly', 0,
   CURRENT_DATE + INTERVAL '15 days', false, NOW()),

  -- Ten classes package with remaining classes
  ('功夫熊猫2024', 'kungfu.panda@test.com', 'ten_classes', 8,
   NULL, false, NOW()),

  -- Two classes package with 1 class remaining
  ('Bruce_Lee_Jr', 'bruce.jr@test.com', 'two_classes', 1,
   NULL, false, NOW()),

  -- Single class member with no remaining class
  ('拳王子@MT', 'boxer.prince@test.com', 'single_class', 0,
   NULL, false, NOW()),

  -- Expired monthly member
  ('旺达Maria', 'wanda.m@test.com', 'single_daily_monthly', 0,
   CURRENT_DATE - INTERVAL '5 days', false, NOW()),

  -- New member without membership
  ('新手小白123', 'newbie123@test.com', NULL, 0,
   NULL, true, NOW()),

  -- Almost expired monthly member
  ('格斗之星', 'fight.star@test.com', 'double_daily_monthly', 0,
   CURRENT_DATE + INTERVAL '2 days', false, NOW());

-- Add some initial check-in records
INSERT INTO check_ins (
  member_id,
  class_type,
  check_in_date,
  created_at,
  is_extra
)
SELECT 
  m.id,
  'morning'::class_type,
  CURRENT_DATE,
  NOW(),
  false
FROM members m
WHERE m.email = 'thai.kid@test.com';

COMMIT;