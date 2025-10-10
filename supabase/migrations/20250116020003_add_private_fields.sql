-- Add private class related fields to check_ins table
BEGIN;

-- Add is_private field
ALTER TABLE check_ins
ADD COLUMN IF NOT EXISTS is_private boolean NOT NULL DEFAULT false;

-- Add is_1v2 field
ALTER TABLE check_ins
ADD COLUMN IF NOT EXISTS is_1v2 boolean NOT NULL DEFAULT false;

-- Add time_slot field
ALTER TABLE check_ins
ADD COLUMN IF NOT EXISTS time_slot text;

COMMIT; 