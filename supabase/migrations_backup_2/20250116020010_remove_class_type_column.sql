-- Remove class_type column from check_ins table
BEGIN;

-- Drop class_type column
ALTER TABLE check_ins DROP COLUMN IF EXISTS class_type;

COMMIT; 