/*
  # Enhance check-in validation

  1. Changes
    - Improve duplicate check-in validation
    - Add better error messages
    - Fix race condition in validation

  2. Security
    - Maintain existing RLS policies
    - Ensure data consistency
*/

-- Enhanced check-in validation function
CREATE OR REPLACE FUNCTION validate_check_in()
RETURNS TRIGGER AS $$
DECLARE
  v_membership membership_type;
  v_membership_expiry timestamptz;
  v_existing_check_in boolean;
BEGIN
  -- Get member details
  SELECT 
    membership,
    membership_expiry
  INTO
    v_membership,
    v_membership_expiry
  FROM members
  WHERE id = NEW.member_id;

  -- Check for existing check-in with FOR UPDATE to prevent race conditions
  SELECT EXISTS (
    SELECT 1
    FROM check_ins
    WHERE member_id = NEW.member_id
    AND check_in_date = CURRENT_DATE
    AND class_type = NEW.class_type
    FOR UPDATE
  ) INTO v_existing_check_in;

  -- Prevent duplicate check-ins
  IF v_existing_check_in THEN
    RAISE EXCEPTION '会员今日已在该时段签到，请选择其他时段。 Member has already checked in for this class type today, please choose another class time.';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate trigger with proper timing
DROP TRIGGER IF EXISTS check_in_validation_trigger ON check_ins;
CREATE TRIGGER check_in_validation_trigger
  BEFORE INSERT ON check_ins
  FOR EACH ROW
  EXECUTE FUNCTION validate_check_in();