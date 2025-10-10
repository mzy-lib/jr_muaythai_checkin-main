BEGIN;

-- 删除已存在的trigger以避免冲突
DROP TRIGGER IF EXISTS validate_check_in_trigger ON check_ins;
DROP TRIGGER IF EXISTS check_in_validation_trigger ON check_ins;

-- 重新创建trigger
CREATE TRIGGER validate_check_in_trigger
    BEFORE INSERT ON check_ins
    FOR EACH ROW
    EXECUTE FUNCTION validate_check_in();

COMMIT; 