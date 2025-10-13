/*
  # Prevent duplicate check-ins for same class type

  1. Changes
    - Add function to validate check-ins before insertion
    - Prevent duplicate check-ins for the same class type on the same day
    - Return clear error messages for failed check-ins

  2. Technical Details
    - Create new validate_check_in() function
    - Add trigger to run validation before check-in
*/

-- Function to validate check-ins
CREATE OR REPLACE FUNCTION validate_check_in()
RETURNS TRIGGER AS $$
DECLARE
  v_membership membership_type;
  v_membership_expiry timestamptz;
  v_same_class_check_ins int;
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

  -- Count check-ins for the same class type today
  SELECT COUNT(*)
  INTO v_same_class_check_ins
  FROM check_ins
  WHERE member_id = NEW.member_id
  AND check_in_date = CURRENT_DATE
  AND class_type = NEW.class_type;

  -- Validate check-in
  IF v_same_class_check_ins > 0 THEN
    RAISE EXCEPTION '会员今日已在该时段签到，请选择其他时段。 Member has already checked in for this class type today, please choose another class time.';
  END IF;

  -- Additional validations can be added here

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for check-in validation
DROP TRIGGER IF EXISTS check_in_validation_trigger ON check_ins;
CREATE TRIGGER check_in_validation_trigger
  BEFORE INSERT ON check_ins
  FOR EACH ROW
  EXECUTE FUNCTION validate_check_in();