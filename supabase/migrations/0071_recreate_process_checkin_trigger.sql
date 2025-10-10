-- Recreate process_check_in trigger
BEGIN;

-- Drop existing triggers if they exist
DROP TRIGGER IF EXISTS process_check_in_trigger ON check_ins;
DROP TRIGGER IF EXISTS check_in_validation_trigger ON check_ins;

-- Create validation trigger first
CREATE TRIGGER check_in_validation_trigger
  BEFORE INSERT ON check_ins
  FOR EACH ROW
  EXECUTE FUNCTION validate_check_in();

-- Create process trigger second
CREATE TRIGGER process_check_in_trigger
  AFTER INSERT ON check_ins
  FOR EACH ROW
  EXECUTE FUNCTION process_check_in();

COMMIT;