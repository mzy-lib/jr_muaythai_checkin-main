/*
  # Test Data Migration with Proper Type Casting

  1. Changes
    - Add test members with various membership types
    - Add check-in records with proper enum casting
    - Use safe transaction handling
  
  2. Safety Measures
    - Proper type casting for enums
    - Check for existing records
    - Safe transaction boundaries
*/

BEGIN;

-- Safely insert test members
DO $$ 
BEGIN
  -- Only insert if email doesn't exist
  INSERT INTO members (
    name,
    email,
    membership,
    remaining_classes,
    membership_expiry,
    is_new_member,
    created_at
  ) 
  SELECT
    '测试会员A',
    'member.a@test.com',
    'single_daily_monthly'::membership_type,
    0,
    NOW() + INTERVAL '15 days',
    false,
    NOW()
  WHERE NOT EXISTS (
    SELECT 1 FROM members WHERE email = 'member.a@test.com'
  );

  INSERT INTO members (
    name,
    email,
    membership,
    remaining_classes,
    membership_expiry,
    is_new_member,
    created_at
  )
  SELECT
    '测试会员B',
    'member.b@test.com',
    'ten_classes'::membership_type,
    5,
    NULL,
    false,
    NOW()
  WHERE NOT EXISTS (
    SELECT 1 FROM members WHERE email = 'member.b@test.com'
  );

  INSERT INTO members (
    name,
    email,
    membership,
    remaining_classes,
    membership_expiry,
    is_new_member,
    created_at
  )
  SELECT
    '测试会员C',
    'member.c@test.com',
    'single_daily_monthly'::membership_type,
    0,
    NOW() - INTERVAL '5 days',
    false,
    NOW()
  WHERE NOT EXISTS (
    SELECT 1 FROM members WHERE email = 'member.c@test.com'
  );

  INSERT INTO members (
    name,
    email,
    membership,
    remaining_classes,
    membership_expiry,
    is_new_member,
    created_at
  )
  SELECT
    '测试会员D',
    'member.d@test.com',
    'single_class'::membership_type,
    0,
    NULL,
    false,
    NOW()
  WHERE NOT EXISTS (
    SELECT 1 FROM members WHERE email = 'member.d@test.com'
  );

  INSERT INTO members (
    name,
    email,
    membership,
    remaining_classes,
    membership_expiry,
    is_new_member,
    created_at
  )
  SELECT
    '测试会员E',
    'member.e@test.com',
    NULL,
    0,
    NULL,
    true,
    NOW()
  WHERE NOT EXISTS (
    SELECT 1 FROM members WHERE email = 'member.e@test.com'
  );

  INSERT INTO members (
    name,
    email,
    membership,
    remaining_classes,
    membership_expiry,
    is_new_member,
    created_at
  )
  SELECT
    '测试会员F',
    'member.f@test.com',
    'double_daily_monthly'::membership_type,
    0,
    NOW() + INTERVAL '20 days',
    false,
    NOW()
  WHERE NOT EXISTS (
    SELECT 1 FROM members WHERE email = 'member.f@test.com'
  );
END $$;

-- Add check-in records for the test members
DO $$
DECLARE
  member_id uuid;
  check_date date;
BEGIN
  -- Regular check-ins for monthly member
  SELECT id INTO member_id FROM members WHERE email = 'member.a@test.com';
  IF member_id IS NOT NULL THEN
    FOR check_date IN SELECT generate_series(NOW() - INTERVAL '7 days', NOW(), '1 day')::date LOOP
      IF EXTRACT(DOW FROM check_date) BETWEEN 1 AND 6 THEN
        INSERT INTO check_ins (member_id, class_type, check_in_date, created_at, is_extra)
        VALUES (member_id, 'morning'::class_type, check_date, check_date + TIME '09:00', false);
      END IF;
    END LOOP;
  END IF;

  -- Check-ins for 10-class package member
  SELECT id INTO member_id FROM members WHERE email = 'member.b@test.com';
  IF member_id IS NOT NULL THEN
    FOR check_date IN SELECT generate_series(NOW() - INTERVAL '5 days', NOW(), '1 day')::date LOOP
      IF EXTRACT(DOW FROM check_date) BETWEEN 1 AND 6 THEN
        INSERT INTO check_ins (member_id, class_type, check_in_date, created_at, is_extra)
        VALUES (
          member_id, 
          CASE WHEN EXTRACT(DOW FROM check_date) % 2 = 0 
            THEN 'morning'::class_type 
            ELSE 'evening'::class_type 
          END,
          check_date, 
          check_date + TIME '09:00',
          false
        );
      END IF;
    END LOOP;
  END IF;

  -- Extra check-ins for expired monthly member
  SELECT id INTO member_id FROM members WHERE email = 'member.c@test.com';
  IF member_id IS NOT NULL THEN
    FOR check_date IN SELECT generate_series(NOW() - INTERVAL '3 days', NOW(), '1 day')::date LOOP
      IF EXTRACT(DOW FROM check_date) BETWEEN 1 AND 6 THEN
        INSERT INTO check_ins (member_id, class_type, check_in_date, created_at, is_extra)
        VALUES (member_id, 'morning'::class_type, check_date, check_date + TIME '09:00', true);
      END IF;
    END LOOP;
  END IF;

  -- Mixed regular and extra check-ins for double daily member
  SELECT id INTO member_id FROM members WHERE email = 'member.f@test.com';
  IF member_id IS NOT NULL THEN
    FOR check_date IN SELECT generate_series(NOW() - INTERVAL '7 days', NOW(), '1 day')::date LOOP
      IF EXTRACT(DOW FROM check_date) BETWEEN 1 AND 6 THEN
        -- Morning class (regular)
        INSERT INTO check_ins (member_id, class_type, check_in_date, created_at, is_extra)
        VALUES (member_id, 'morning'::class_type, check_date, check_date + TIME '09:00', false);
        
        -- Evening class (sometimes extra)
        INSERT INTO check_ins (member_id, class_type, check_in_date, created_at, is_extra)
        VALUES (
          member_id, 
          'evening'::class_type, 
          check_date, 
          check_date + TIME '17:00', 
          EXTRACT(DOW FROM check_date) % 2 = 0
        );
      END IF;
    END LOOP;
  END IF;
END $$;

COMMIT;