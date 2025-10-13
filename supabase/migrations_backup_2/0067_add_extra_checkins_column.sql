-- Add extra_check_ins column to members table
BEGIN;

-- Add the column if it doesn't exist
ALTER TABLE members
ADD COLUMN IF NOT EXISTS extra_check_ins integer DEFAULT 0;

-- Update existing records to have 0 extra check-ins if NULL
UPDATE members
SET extra_check_ins = 0
WHERE extra_check_ins IS NULL;

-- Set the column to NOT NULL
ALTER TABLE members
ALTER COLUMN extra_check_ins SET NOT NULL;

COMMIT; 