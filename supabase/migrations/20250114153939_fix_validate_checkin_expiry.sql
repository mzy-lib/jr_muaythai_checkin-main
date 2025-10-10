BEGIN;

-- 更新validate_check_in函数，修复过期验证
CREATE OR REPLACE FUNCTION validate_check_in()
RETURNS TRIGGER AS $$
DECLARE
  v_member RECORD;
  v_daily_check_ins integer;
  v_same_class_check_ins integer;
BEGIN
  -- Get member details
  SELECT *
  INTO v_member
  FROM members
  WHERE id = NEW.member_id;

  -- Check for duplicate check-in in same class type
  SELECT COUNT(*)
  INTO v_same_class_check_ins
  FROM check_ins
  WHERE member_id = NEW.member_id
    AND check_in_date = NEW.check_in_date
    AND class_type = NEW.class_type;

  IF v_same_class_check_ins > 0 THEN
    RAISE EXCEPTION '您今天已在该时段签到。请返回首页选择其他时段。'
      USING HINT = 'duplicate_checkin';
  END IF;

  -- Count today's regular check-ins
  SELECT COUNT(*)
  INTO v_daily_check_ins
  FROM check_ins
  WHERE member_id = NEW.member_id
    AND check_in_date = NEW.check_in_date
    AND is_extra = false;

  -- Set is_extra based on membership rules
  NEW.is_extra := CASE
    -- New member or no membership
    WHEN v_member.is_new_member OR v_member.membership IS NULL THEN
      true
    -- Monthly memberships
    WHEN v_member.membership IN ('single_monthly', 'double_monthly') THEN
      CASE
        -- Expired membership
        WHEN v_member.membership_expiry < CURRENT_DATE THEN
          true
        -- Single monthly reached limit
        WHEN v_member.membership = 'single_monthly' AND v_daily_check_ins >= 1 THEN
          true
        -- Double monthly reached limit
        WHEN v_member.membership = 'double_monthly' AND v_daily_check_ins >= 2 THEN
          true
        -- Within limits
        ELSE
          false
      END
    -- Class-based memberships
    WHEN v_member.membership IN ('single_class', 'two_classes', 'ten_classes') THEN
      v_member.remaining_classes <= 0
    -- Unknown membership type (safety)
    ELSE
      true
  END;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMIT; 