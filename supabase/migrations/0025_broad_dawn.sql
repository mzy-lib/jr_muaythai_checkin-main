-- Enhanced check-in validation and processing
CREATE OR REPLACE FUNCTION process_check_in()
RETURNS TRIGGER AS $$
DECLARE
  v_membership membership_type;
  v_remaining_classes int;
  v_membership_expiry timestamptz;
  v_daily_check_ins int;
  v_same_class_check_ins int;
BEGIN
  -- Get member details with lock
  SELECT 
    membership,
    remaining_classes,
    membership_expiry
  INTO
    v_membership,
    v_remaining_classes,
    v_membership_expiry
  FROM members
  WHERE id = NEW.member_id
  FOR UPDATE;

  -- Check for same class type check-ins today
  SELECT COUNT(*)
  INTO v_same_class_check_ins
  FROM check_ins
  WHERE member_id = NEW.member_id
    AND check_in_date = CURRENT_DATE
    AND class_type = NEW.class_type;

  IF v_same_class_check_ins > 0 THEN
    RAISE EXCEPTION '您今天已在该时段签到。请返回首页选择其他时段。You have already checked in for this class type today. Please return home and choose another class time.'
      USING HINT = 'duplicate_class';
  END IF;

  -- Count total daily check-ins
  SELECT COUNT(*)
  INTO v_daily_check_ins
  FROM check_ins
  WHERE member_id = NEW.member_id
    AND check_in_date = CURRENT_DATE
    AND is_extra = false;

  -- Determine if this is an extra check-in
  NEW.is_extra := CASE
    -- No membership
    WHEN v_membership IS NULL THEN 
      true
    
    -- Monthly memberships
    WHEN v_membership IN ('single_daily_monthly', 'double_daily_monthly') THEN
      CASE
        -- Expired membership
        WHEN v_membership_expiry < CURRENT_DATE THEN 
          true
        -- Single daily reached limit
        WHEN v_membership = 'single_daily_monthly' AND v_daily_check_ins >= 1 THEN
          true
        -- Double daily reached limit
        WHEN v_membership = 'double_daily_monthly' AND v_daily_check_ins >= 2 THEN
          true
        -- Within limits
        ELSE
          false
      END
    
    -- Class-based memberships
    WHEN v_membership IN ('single_class', 'two_classes', 'ten_classes') THEN
      v_remaining_classes <= 0
    
    -- Unknown membership type (safety)
    ELSE
      true
  END;

  -- Update member information
  IF NOT NEW.is_extra THEN
    -- Decrement remaining classes for class-based memberships
    IF v_membership IN ('single_class', 'two_classes', 'ten_classes') THEN
      UPDATE members
      SET remaining_classes = remaining_classes - 1
      WHERE id = NEW.member_id;
    END IF;
  ELSE
    -- Increment extra check-ins counter
    UPDATE members
    SET extra_check_ins = extra_check_ins + 1
    WHERE id = NEW.member_id;
  END IF;

  -- Update new member status
  UPDATE members
  SET is_new_member = false
  WHERE id = NEW.member_id
    AND is_new_member = true;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add test data for different scenarios
INSERT INTO members (
  name,
  email,
  membership,
  remaining_classes,
  membership_expiry,
  is_new_member,
  created_at
) VALUES
  -- Active single daily monthly member
  ('测试会员A', 'test.a@example.com', 'single_daily_monthly', 0, 
   CURRENT_DATE + INTERVAL '30 days', false, NOW()),

  -- Active double daily monthly member
  ('测试会员B', 'test.b@example.com', 'double_daily_monthly', 0,
   CURRENT_DATE + INTERVAL '30 days', false, NOW()),

  -- Ten classes package with remaining classes
  ('测试会员C', 'test.c@example.com', 'ten_classes', 5,
   NULL, false, NOW()),

  -- Ten classes package with no remaining classes
  ('测试会员D', 'test.d@example.com', 'ten_classes', 0,
   NULL, false, NOW()),

  -- Expired monthly member
  ('测试会员E', 'test.e@example.com', 'single_daily_monthly', 0,
   CURRENT_DATE - INTERVAL '5 days', false, NOW()),

  -- New member without membership
  ('测试会员F', 'test.f@example.com', NULL, 0,
   NULL, true, NOW());