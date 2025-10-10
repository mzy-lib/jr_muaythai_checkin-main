BEGIN;

-- 删除所有已存在的trigger
DROP TRIGGER IF EXISTS check_duplicate_name_trigger ON members;
DROP TRIGGER IF EXISTS process_check_in_trigger ON check_ins;
DROP TRIGGER IF EXISTS validate_check_in_trigger ON check_ins;

-- 重新创建members表的trigger
CREATE TRIGGER check_duplicate_name_trigger
    BEFORE INSERT OR UPDATE ON members
    FOR EACH ROW
    EXECUTE FUNCTION check_duplicate_name();

-- 重新创建check_ins表的triggers，确保正确的执行顺序
CREATE TRIGGER validate_check_in_trigger
    BEFORE INSERT ON check_ins
    FOR EACH ROW
    EXECUTE FUNCTION validate_check_in();

CREATE TRIGGER process_check_in_trigger
    AFTER INSERT ON check_ins
    FOR EACH ROW
    EXECUTE FUNCTION process_check_in();

COMMIT; 