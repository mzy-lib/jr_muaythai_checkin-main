CREATE OR REPLACE FUNCTION validate_check_in()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
  v_member RECORD;
  v_daily_check_ins integer;
  v_has_same_class_check_in boolean;
BEGIN
  -- Get member details
  SELECT *
  INTO v_member
  FROM members
  WHERE id = NEW.member_id;

  -- Check if member exists
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member not found';
  END IF;

  -- Check if member has checked in for the same class type today
  SELECT EXISTS (
    SELECT 1
    FROM check_ins
    WHERE member_id = NEW.member_id
      AND check_in_date = NEW.check_in_date
      AND class_type = NEW.class_type
      AND id IS DISTINCT FROM NEW.id  -- 排除当前记录
  ) INTO v_has_same_class_check_in;

  -- Prevent duplicate check-ins for the same class type on the same day
  IF v_has_same_class_check_in THEN
    RAISE EXCEPTION 'Already checked in for this class type today'
      USING HINT = 'duplicate_checkin';
  END IF;

  -- Get daily check-ins count for the member (excluding current record)
  SELECT COUNT(*)
  INTO v_daily_check_ins
  FROM check_ins
  WHERE member_id = NEW.member_id
    AND check_in_date = NEW.check_in_date
    AND is_extra = false
    AND id IS DISTINCT FROM NEW.id;  -- 排除当前记录

  -- Set is_extra flag based on membership type and conditions
  NEW.is_extra := CASE
    -- 新会员首次签到标记为额外签到
    WHEN v_member.is_new_member THEN true
    -- 月卡过期标记为额外签到
    WHEN v_member.membership IN ('single_monthly', 'double_monthly') 
      AND v_member.membership_expiry < CURRENT_DATE THEN true
    -- 单次月卡每天限1次
    WHEN v_member.membership = 'single_monthly' 
      AND v_daily_check_ins >= 1 THEN true
    -- 双次月卡每天限2次
    WHEN v_member.membership = 'double_monthly' 
      AND v_daily_check_ins >= 2 THEN true
    -- 次卡会员且剩余次数为0
    WHEN v_member.membership IN ('single_class', 'two_classes', 'ten_classes') 
      AND v_member.remaining_classes <= 0 THEN true
    -- 其他情况为正常签到
    ELSE false
  END;

  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION process_check_in()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
  -- Update member information
  UPDATE members
  SET
    -- Update remaining classes for class-based memberships
    remaining_classes = CASE
      WHEN membership IN ('single_class', 'two_classes', 'ten_classes')
        AND remaining_classes > 0
        AND NOT NEW.is_extra  -- 只在非额外签到时扣减
      THEN remaining_classes - 1
      ELSE remaining_classes
    END,
    -- Update last check-in date
    last_check_in_date = NEW.check_in_date,
    -- Update daily check-ins counter
    daily_check_ins = CASE
      WHEN last_check_in_date = NEW.check_in_date THEN daily_check_ins + 1
      ELSE 1
    END,
    -- Update extra check-ins counter
    extra_check_ins = CASE
      WHEN NEW.is_extra THEN extra_check_ins + 1
      ELSE extra_check_ins
    END,
    -- Remove new member status after first check-in
    is_new_member = CASE
      WHEN is_new_member THEN false
      ELSE is_new_member
    END
  WHERE id = NEW.member_id;

  RETURN NEW;
END;
$function$;

-- 删除已存在的触发器
DROP TRIGGER IF EXISTS validate_check_in_trigger ON check_ins;
DROP TRIGGER IF EXISTS process_check_in_trigger ON check_ins;

-- 创建新的触发器
CREATE TRIGGER validate_check_in_trigger
  BEFORE INSERT ON check_ins
  FOR EACH ROW
  EXECUTE FUNCTION validate_check_in();

CREATE TRIGGER process_check_in_trigger
  AFTER INSERT ON check_ins
  FOR EACH ROW
  EXECUTE FUNCTION process_check_in(); 