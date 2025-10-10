-- Add process_check_in trigger
BEGIN;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS process_check_in_trigger ON check_ins;

-- Create new trigger
CREATE TRIGGER process_check_in_trigger
  AFTER INSERT ON check_ins
  FOR EACH ROW
  EXECUTE FUNCTION process_check_in();

COMMIT; 