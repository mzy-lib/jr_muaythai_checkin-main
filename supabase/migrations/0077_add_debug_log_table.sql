BEGIN;

-- 创建日志表
CREATE TABLE IF NOT EXISTS debug_logs (
  id SERIAL PRIMARY KEY,
  timestamp TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  function_name TEXT NOT NULL,
  member_id UUID,
  message TEXT NOT NULL,
  details JSONB
);

-- 重新创建 validate_check_in 函数
CREATE OR REPLACE FUNCTION validate_check_in()
RETURNS TRIGGER AS $$
DECLARE
  v_member members;
  v_same_class_check_ins INTEGER;
  v_daily_check_ins INTEGER;
  v_reason TEXT;
BEGIN
  -- 获取会员信息
  SELECT * INTO v_member
  FROM members
  WHERE id = NEW.member_id;

  -- 记录会员信息
  INSERT INTO debug_logs (function_name, member_id, message, details)
  VALUES (
    'validate_check_in',
    v_member.id,
    '会员信息',
    jsonb_build_object(
      'membership', v_member.membership,
      'remaining_classes', v_member.remaining_classes,
      'is_new_member', v_member.is_new_member
    )
  );

  -- 检查是否已经签到
  SELECT COUNT(*) INTO v_same_class_check_ins
  FROM check_ins
  WHERE member_id = NEW.member_id
  AND check_in_date = NEW.check_in_date
  AND class_type = NEW.class_type;

  IF v_same_class_check_ins > 0 THEN
    RAISE EXCEPTION '您今天已在该时段签到。请返回首页选择其他时段。You have already checked in for this class type today. Please return home and choose another class time.'
      USING HINT = 'duplicate_checkin';
  END IF;

  -- 获取会员今日有效签到次数
  SELECT COUNT(*) INTO v_daily_check_ins
  FROM check_ins
  WHERE member_id = NEW.member_id
  AND check_in_date = NEW.check_in_date
  AND is_extra = false;

  -- 记录签到次数
  INSERT INTO debug_logs (function_name, member_id, message, details)
  VALUES (
    'validate_check_in',
    v_member.id,
    '今日有效签到次数',
    jsonb_build_object('daily_check_ins', v_daily_check_ins)
  );

  -- 设置 is_extra 标志
  IF v_member.is_new_member THEN
    NEW.is_extra := true;
    v_reason := '新会员，设置extra=true';
  ELSIF v_member.membership_expiry < CURRENT_DATE AND v_member.membership NOT IN ('single_class', 'two_classes', 'ten_classes') THEN
    NEW.is_extra := true;
    v_reason := '月卡过期，设置extra=true';
  ELSIF v_member.membership IN ('single_class', 'two_classes', 'ten_classes') AND v_member.remaining_classes = 0 THEN
    NEW.is_extra := true;
    v_reason := '课时卡次数用完，设置extra=true';
  ELSIF v_member.membership = 'single_monthly' AND v_daily_check_ins > 0 THEN
    NEW.is_extra := true;
    v_reason := '单次月卡超出限制，设置extra=true';
  ELSIF v_member.membership = 'double_monthly' AND v_daily_check_ins > 1 THEN
    NEW.is_extra := true;
    v_reason := '双次月卡超出限制，设置extra=true';
  ELSE
    NEW.is_extra := false;
    v_reason := '正常签到，设置extra=false';
  END IF;

  -- 记录设置原因
  INSERT INTO debug_logs (function_name, member_id, message, details)
  VALUES (
    'validate_check_in',
    v_member.id,
    v_reason,
    jsonb_build_object(
      'is_extra', NEW.is_extra,
      'membership', v_member.membership,
      'remaining_classes', v_member.remaining_classes,
      'is_new_member', v_member.is_new_member,
      'daily_check_ins', v_daily_check_ins
    )
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 重新创建 process_check_in 函数
CREATE OR REPLACE FUNCTION process_check_in()
RETURNS TRIGGER AS $$
DECLARE
  v_old_remaining_classes INTEGER;
  v_new_remaining_classes INTEGER;
  v_membership TEXT;
BEGIN
  -- 记录更新前的课时数
  SELECT remaining_classes, membership INTO v_old_remaining_classes, v_membership
  FROM members
  WHERE id = NEW.member_id;

  -- 记录处理开始
  INSERT INTO debug_logs (function_name, member_id, message, details)
  VALUES (
    'process_check_in',
    NEW.member_id,
    '开始处理',
    jsonb_build_object(
      'membership', v_membership,
      'is_extra', NEW.is_extra,
      'old_remaining_classes', v_old_remaining_classes
    )
  );

  -- 更新会员信息
  UPDATE members
  SET 
    remaining_classes = CASE 
      WHEN membership IN ('single_class', 'two_classes', 'ten_classes') 
           AND NOT NEW.is_extra 
      THEN remaining_classes - 1
      ELSE remaining_classes
    END,
    extra_check_ins = CASE 
      WHEN NEW.is_extra 
      THEN extra_check_ins + 1
      ELSE extra_check_ins
    END,
    daily_check_ins = daily_check_ins + 1,
    last_check_in_date = NEW.check_in_date,
    is_new_member = false
  WHERE id = NEW.member_id
  RETURNING remaining_classes INTO v_new_remaining_classes;

  -- 记录更新结果
  INSERT INTO debug_logs (function_name, member_id, message, details)
  VALUES (
    'process_check_in',
    NEW.member_id,
    '更新完成',
    jsonb_build_object(
      'membership', v_membership,
      'is_extra', NEW.is_extra,
      'old_remaining_classes', v_old_remaining_classes,
      'new_remaining_classes', v_new_remaining_classes,
      'changed', (v_old_remaining_classes != v_new_remaining_classes)
    )
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMIT; 