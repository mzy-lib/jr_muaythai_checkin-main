-- Clear check-in records while preserving member data
BEGIN;

-- Reset extra check-ins counter for all members
UPDATE members
SET extra_check_ins = 0;

-- Delete all check-in records
DELETE FROM check_ins;

-- Add a comment to document the cleanup
COMMENT ON TABLE check_ins IS 'Check-in records - Reset on 2024-03-20';

COMMIT;