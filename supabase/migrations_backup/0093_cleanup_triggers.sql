BEGIN;

-- 删除旧的触发器
DROP TRIGGER IF EXISTS check_in_processing_trigger ON check_ins;
DROP TRIGGER IF EXISTS check_in_validation_trigger ON check_ins;

-- 删除并重新创建最新的触发器
DROP TRIGGER IF EXISTS validate_check_in_trigger ON check_ins;
DROP TRIGGER IF EXISTS process_check_in_trigger ON check_ins;

-- 重新创建验证触发器
CREATE TRIGGER validate_check_in_trigger
  BEFORE INSERT ON check_ins
  FOR EACH ROW
  EXECUTE FUNCTION validate_check_in();

-- 重新创建处理触发器
CREATE TRIGGER process_check_in_trigger
  BEFORE INSERT ON check_ins
  FOR EACH ROW
  EXECUTE FUNCTION process_check_in();

COMMIT; 