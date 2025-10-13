-- Clean up check-in records while preserving test members
BEGIN;

-- Delete all check-ins for test members
DELETE FROM check_ins 
WHERE member_id IN (
  SELECT id 
  FROM members 
  WHERE email LIKE '%.test.mt@example.com'
);

-- Reset extra_check_ins counter for test members
UPDATE members 
SET extra_check_ins = 0
WHERE email LIKE '%.test.mt@example.com';

COMMIT;

COMMENT ON TABLE check_ins IS 'Check-in records - Reset for testing on 2024-03-20';