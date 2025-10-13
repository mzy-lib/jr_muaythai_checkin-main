/*
  # Update Test Data with Realistic Names

  1. Changes
    - Add test members with realistic Chinese, English and WeChat-style names
    - Include various membership types and states
    - Add corresponding check-in records
  
  2. Safety Measures
    - Use safe inserts with email checks
    - Proper type casting for enums
    - Transaction boundaries
*/

BEGIN;

-- Safely insert test members with realistic names
DO $$ 
BEGIN
  -- Monthly membership member with Chinese name
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
    '小龙女_2024',
    'xiaolongnv@test.com',
    'single_daily_monthly'::membership_type,
    0,
    NOW() + INTERVAL '15 days',
    false,
    NOW()
  WHERE NOT EXISTS (
    SELECT 1 FROM members WHERE email = 'xiaolongnv@test.com'
  );

  -- Ten-class package member with English name
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
    'Tiger Wong',
    'tiger.wong@test.com',
    'ten_classes'::membership_type,
    5,
    NULL,
    false,
    NOW()
  WHERE NOT EXISTS (
    SELECT 1 FROM members WHERE email = 'tiger.wong@test.com'
  );

  -- Expired monthly member with WeChat style name
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
    'MT_Fighter88',
    'fighter88@test.com',
    'single_daily_monthly'::membership_type,
    0,
    NOW() - INTERVAL '5 days',
    false,
    NOW()
  WHERE NOT EXISTS (
    SELECT 1 FROM members WHERE email = 'fighter88@test.com'
  );

  -- Single class member with mixed language name
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
    '李Anna',
    'anna.li@test.com',
    'single_class'::membership_type,
    0,
    NULL,
    false,
    NOW()
  WHERE NOT EXISTS (
    SELECT 1 FROM members WHERE email = 'anna.li@test.com'
  );

  -- New member with modern Chinese name
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
    '酷龙-KL',
    'kl2024@test.com',
    NULL,
    0,
    NULL,
    true,
    NOW()
  WHERE NOT EXISTS (
    SELECT 1 FROM members WHERE email = 'kl2024@test.com'
  );

  -- Double daily member with professional name
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
    'Coach Mike Chen',
    'mike.chen@test.com',
    'double_daily_monthly'::membership_type,
    0,
    NOW() + INTERVAL '20 days',
    false,
    NOW()
  WHERE NOT EXISTS (
    SELECT 1 FROM members WHERE email = 'mike.chen@test.com'
  );
END $$;

-- Add check-in records for the test members
DO $$
DECLARE
  member_id uuid;
  check_date date;
BEGIN
  -- Regular check-ins for monthly member
  SELECT id INTO member_id FROM members WHERE email = 'xiaolongnv@test.com';
  IF member_id IS NOT NULL THEN
    FOR check_date IN SELECT generate_series(NOW() - INTERVAL '7 days', NOW(), '1 day')::date LOOP
      IF EXTRACT(DOW FROM check_date) BETWEEN 1 AND 6 THEN
        INSERT INTO check_ins (member_id, class_type, check_in_date, created_at, is_extra)
        VALUES (member_id, 'morning'::class_type, check_date, check_date + TIME '09:00', false);
      END IF;
    END LOOP;
  END IF;

  -- Mixed schedule for Tiger Wong
  SELECT id INTO member_id FROM members WHERE email = 'tiger.wong@test.com';
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

  -- Extra check-ins for expired member
  SELECT id INTO member_id FROM members WHERE email = 'fighter88@test.com';
  IF member_id IS NOT NULL THEN
    FOR check_date IN SELECT generate_series(NOW() - INTERVAL '3 days', NOW(), '1 day')::date LOOP
      IF EXTRACT(DOW FROM check_date) BETWEEN 1 AND 6 THEN
        INSERT INTO check_ins (member_id, class_type, check_in_date, created_at, is_extra)
        VALUES (member_id, 'morning'::class_type, check_date, check_date + TIME '09:00', true);
      END IF;
    END LOOP;
  END IF;

  -- Intensive training schedule for Coach Mike
  SELECT id INTO member_id FROM members WHERE email = 'mike.chen@test.com';
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