-- Fix check_in_date default value
BEGIN;

-- Drop existing default if any
ALTER TABLE check_ins 
  ALTER COLUMN check_in_date DROP DEFAULT;

-- Add correct default
ALTER TABLE check_ins 
  ALTER COLUMN check_in_date SET DEFAULT CURRENT_DATE;

-- Ensure the column is NOT NULL
ALTER TABLE check_ins 
  ALTER COLUMN check_in_date SET NOT NULL;

COMMIT; 