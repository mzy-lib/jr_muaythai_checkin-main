-- Recreate check-in validation trigger
BEGIN;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS check_in_validation_trigger ON check_ins;

-- Create new trigger
CREATE TRIGGER check_in_validation_trigger
  BEFORE INSERT ON check_ins
  FOR EACH ROW
  EXECUTE FUNCTION validate_check_in();

COMMIT; 