/*
  # Update Schema for JR Muay Thai Sign-in System

  1. Changes
    - Add trigger-based daily check-in limit enforcement
    - Add duplicate name handling
    - Add automatic new member status update
    
  2. Security
    - Ensures data integrity through triggers
*/

-- Function to validate daily check-in limits
CREATE OR REPLACE FUNCTION validate_check_in()
RETURNS TRIGGER AS $$
DECLARE
  daily_count INTEGER;
  member_type membership_type;
  allowed_count INTEGER;
BEGIN
  -- Get member's membership type
  SELECT membership INTO member_type
  FROM members 
  WHERE id = NEW.member_id;

  -- Count existing check-ins for the day
  SELECT COUNT(*) INTO daily_count
  FROM check_ins
  WHERE member_id = NEW.member_id
  AND check_in_date = NEW.check_in_date;

  -- Determine allowed count based on membership
  allowed_count := CASE member_type
    WHEN 'single_daily_monthly' THEN 1
    WHEN 'double_daily_monthly' THEN 2
    ELSE 999 -- No practical limit for other types
  END;

  -- Validate check-in
  IF daily_count >= allowed_count THEN
    NEW.is_extra := true;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for check-in validation
CREATE TRIGGER check_in_validation_trigger
  BEFORE INSERT ON check_ins
  FOR EACH ROW
  EXECUTE FUNCTION validate_check_in();

-- Function to handle duplicate names
CREATE OR REPLACE FUNCTION check_duplicate_name()
RETURNS TRIGGER AS $$
DECLARE
  existing_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO existing_count
  FROM members 
  WHERE LOWER(TRIM(name)) = LOWER(TRIM(NEW.name))
  AND id != NEW.id;

  IF existing_count > 0 AND NEW.email IS NULL THEN
    RAISE EXCEPTION 'Duplicate name found. Email is required for verification.';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for duplicate name checking
CREATE TRIGGER check_duplicate_name_trigger
  BEFORE INSERT OR UPDATE ON members
  FOR EACH ROW
  EXECUTE FUNCTION check_duplicate_name();

-- Function to merge new members into regular members
CREATE OR REPLACE FUNCTION merge_new_members()
RETURNS void AS $$
BEGIN
  UPDATE members
  SET is_new_member = false
  WHERE is_new_member = true
  AND created_at < CURRENT_DATE;
END;
$$ LANGUAGE plpgsql;

-- Create a scheduled function to run daily
CREATE EXTENSION IF NOT EXISTS pg_cron;

SELECT cron.schedule(
  'merge-new-members-daily',
  '0 23 * * *',
  $$SELECT merge_new_members()$$
);