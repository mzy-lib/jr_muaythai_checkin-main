-- Drop existing triggers
DROP TRIGGER IF EXISTS check_in_validation_trigger ON check_ins;
DROP TRIGGER IF EXISTS validate_check_in_trigger ON check_ins;
DROP TRIGGER IF EXISTS check_in_processing_trigger ON check_ins;
DROP TRIGGER IF EXISTS process_check_in_trigger ON check_ins;

-- Recreate triggers with correct order
CREATE TRIGGER validate_check_in_trigger
    BEFORE INSERT ON check_ins
    FOR EACH ROW
    EXECUTE FUNCTION validate_check_in();

CREATE TRIGGER process_check_in_trigger
    AFTER INSERT ON check_ins
    FOR EACH ROW
    EXECUTE FUNCTION process_check_in(); 