/*
  # Add mock data for testing

  1. Test Data Overview
    - Creates test members with different membership types
    - Adds check-in records with various scenarios
    - Includes both regular and extra check-ins

  2. Changes
    - Add test members with different membership types
    - Add check-in records for testing
    - Uses safe SQL practices with error handling
*/

-- Wrap everything in a transaction
BEGIN;

-- Create test members safely
DO $$ 
BEGIN
  -- Member 1: Ten-class package with 5 classes remaining
  INSERT INTO members (
    id, name, email, membership, remaining_classes, is_new_member
  ) VALUES (
    '11111111-1111-1111-1111-111111111111',
    'Test Member 1',
    'test1@example.com',
    'ten_classes',
    5,
    false
  ) ON CONFLICT (id) DO NOTHING;

  -- Member 2: Active single daily monthly
  INSERT INTO members (
    id, name, email, membership, membership_expiry, is_new_member
  ) VALUES (
    '22222222-2222-2222-2222-222222222222',
    'Test Member 2',
    'test2@example.com',
    'single_daily_monthly',
    CURRENT_DATE + INTERVAL '15 days',
    false
  ) ON CONFLICT (id) DO NOTHING;

  -- Member 3: Expired double daily monthly
  INSERT INTO members (
    id, name, email, membership, membership_expiry, is_new_member
  ) VALUES (
    '33333333-3333-3333-3333-333333333333',
    'Test Member 3',
    'test3@example.com',
    'double_daily_monthly',
    CURRENT_DATE - INTERVAL '5 days',
    false
  ) ON CONFLICT (id) DO NOTHING;

  -- Member 4: Single class with no remaining classes
  INSERT INTO members (
    id, name, email, membership, remaining_classes, is_new_member
  ) VALUES (
    '44444444-4444-4444-4444-444444444444',
    'Test Member 4',
    'test4@example.com',
    'single_class',
    0,
    false
  ) ON CONFLICT (id) DO NOTHING;

  -- Member 5: Two classes with 2 remaining
  INSERT INTO members (
    id, name, email, membership, remaining_classes, is_new_member
  ) VALUES (
    '55555555-5555-5555-5555-555555555555',
    'Test Member 5',
    'test5@example.com',
    'two_classes',
    2,
    false
  ) ON CONFLICT (id) DO NOTHING;
END $$;

-- Add check-in records safely
DO $$
DECLARE
  current_date DATE := CURRENT_DATE;
  past_date DATE;
  i INTEGER;
BEGIN
  -- Regular check-ins for member 1 (ten_classes)
  FOR i IN 1..5 LOOP
    past_date := current_date - (i || ' days')::INTERVAL;
    
    INSERT INTO check_ins (
      member_id,
      class_type,
      check_in_date,
      created_at,
      is_extra
    ) VALUES (
      '11111111-1111-1111-1111-111111111111',
      CASE WHEN i % 2 = 0 THEN 'morning'::class_type ELSE 'evening'::class_type END,
      past_date,
      past_date + TIME '09:00:00',
      false
    );
  END LOOP;

  -- Check-ins for member 2 (single_daily_monthly)
  FOR i IN 1..7 LOOP
    past_date := current_date - (i || ' days')::INTERVAL;
    
    -- Morning class (regular)
    INSERT INTO check_ins (
      member_id,
      class_type,
      check_in_date,
      created_at,
      is_extra
    ) VALUES (
      '22222222-2222-2222-2222-222222222222',
      'morning'::class_type,
      past_date,
      past_date + TIME '09:00:00',
      false
    );
    
    -- Evening class (extra) every other day
    IF i % 2 = 0 THEN
      INSERT INTO check_ins (
        member_id,
        class_type,
        check_in_date,
        created_at,
        is_extra
      ) VALUES (
        '22222222-2222-2222-2222-222222222222',
        'evening'::class_type,
        past_date,
        past_date + TIME '17:00:00',
        true
      );
    END IF;
  END LOOP;

  -- Check-ins for member 3 (expired double_daily_monthly)
  FOR i IN 1..5 LOOP
    past_date := current_date - (i || ' days')::INTERVAL;
    
    INSERT INTO check_ins (
      member_id,
      class_type,
      check_in_date,
      created_at,
      is_extra
    ) VALUES (
      '33333333-3333-3333-3333-333333333333',
      'morning'::class_type,
      past_date,
      past_date + TIME '09:00:00',
      past_date > current_date - INTERVAL '5 days'
    );
  END LOOP;

  -- Extra check-ins for member 4 (no remaining classes)
  FOR i IN 1..3 LOOP
    past_date := current_date - (i || ' days')::INTERVAL;
    
    INSERT INTO check_ins (
      member_id,
      class_type,
      check_in_date,
      created_at,
      is_extra
    ) VALUES (
      '44444444-4444-4444-4444-444444444444',
      CASE WHEN i % 2 = 0 THEN 'morning'::class_type ELSE 'evening'::class_type END,
      past_date,
      past_date + TIME '09:00:00',
      true
    );
  END LOOP;

  -- Mixed check-ins for member 5
  FOR i IN 1..4 LOOP
    past_date := current_date - (i || ' days')::INTERVAL;
    
    INSERT INTO check_ins (
      member_id,
      class_type,
      check_in_date,
      created_at,
      is_extra
    ) VALUES (
      '55555555-5555-5555-5555-555555555555',
      CASE WHEN i % 2 = 0 THEN 'morning'::class_type ELSE 'evening'::class_type END,
      past_date,
      past_date + TIME '09:00:00',
      i > 2  -- First 2 regular, last 2 extra
    );
  END LOOP;
END $$;

COMMIT;