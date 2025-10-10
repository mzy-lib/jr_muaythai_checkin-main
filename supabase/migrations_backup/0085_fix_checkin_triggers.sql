BEGIN;

-- 删除现有触发器
DROP TRIGGER IF EXISTS check_in_validation_trigger ON check_ins;
DROP TRIGGER IF EXISTS process_check_in_trigger ON check_ins;

-- 创建验证触发器
CREATE TRIGGER check_in_validation_trigger
  BEFORE INSERT ON check_ins
  FOR EACH ROW
  EXECUTE FUNCTION validate_check_in();

-- 创建处理触发器
CREATE TRIGGER process_check_in_trigger
  AFTER INSERT ON check_ins
  FOR EACH ROW
  EXECUTE FUNCTION process_check_in();

COMMIT; 