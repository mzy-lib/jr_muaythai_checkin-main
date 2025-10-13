/*
  # Test Data for Check-in System

  1. New Tables
    - Adds test members with various membership types and states
    - Adds initial check-in records for testing

  2. Test Cases
    - Monthly membership (active/expired)
    - Class-based membership (with/without remaining classes)
    - New members
    - Members with duplicate names
    - Special character handling in names
*/

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
  -- Active monthly memberships
  ('张三', 'zhang.san.test.mt@example.com', 'single_daily_monthly', 0, 
   CURRENT_DATE + INTERVAL '30 days', false, NOW()),
   
  ('李四', 'li.si.test.mt@example.com', 'double_daily_monthly', 0,
   CURRENT_DATE + INTERVAL '15 days', false, NOW()),

  -- Expired monthly memberships   
  ('王五', 'wang.wu.test.mt@example.com', 'single_daily_monthly', 0,
   CURRENT_DATE - INTERVAL '5 days', false, NOW()),

  -- Class-based memberships with remaining classes
  ('赵六', 'zhao.liu.test.mt@example.com', 'ten_classes', 5,
   NULL, false, NOW()),
   
  ('孙七', 'sun.qi.test.mt@example.com', 'two_classes', 2,
   NULL, false, NOW()),

  -- Class-based membership with no remaining classes
  ('周八', 'zhou.ba.test.mt@example.com', 'single_class', 0,
   NULL, false, NOW()),

  -- Members with duplicate names
  ('王小明', 'wang.xm1.test.mt@example.com', 'ten_classes', 3,
   NULL, false, NOW()),
   
  ('王小明', 'wang.xm2.test.mt@example.com', 'single_daily_monthly', 0,
   CURRENT_DATE + INTERVAL '15 days', false, NOW()),

  -- Special character names
  ('MT-Fighter2024', 'mt.fighter.test.mt@example.com', 'double_daily_monthly', 0,
   CURRENT_DATE + INTERVAL '30 days', false, NOW()),
   
  ('李Anna', 'li.anna.test.mt@example.com', 'ten_classes', 8,
   NULL, false, NOW()),

  -- New member
  ('新学员', 'new.member.test.mt@example.com', NULL, 0,
   NULL, true, NOW());

-- Add some initial check-in records
DO $$
DECLARE
  v_member_id uuid;
BEGIN
  -- Add check-ins for single daily monthly member
  SELECT id INTO v_member_id FROM members WHERE email = 'zhang.san.test.mt@example.com';
  INSERT INTO check_ins (member_id, class_type, check_in_date, is_extra)
  VALUES (v_member_id, 'morning', CURRENT_DATE, false);

  -- Add check-ins for double daily monthly member
  SELECT id INTO v_member_id FROM members WHERE email = 'li.si.test.mt@example.com';
  INSERT INTO check_ins (member_id, class_type, check_in_date, is_extra)
  VALUES 
    (v_member_id, 'morning', CURRENT_DATE, false),
    (v_member_id, 'evening', CURRENT_DATE, false);

  -- Add extra check-in for expired member
  SELECT id INTO v_member_id FROM members WHERE email = 'wang.wu.test.mt@example.com';
  INSERT INTO check_ins (member_id, class_type, check_in_date, is_extra)
  VALUES (v_member_id, 'morning', CURRENT_DATE, true);
END $$;

COMMIT;