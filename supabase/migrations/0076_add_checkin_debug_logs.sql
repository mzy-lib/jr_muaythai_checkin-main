BEGIN;

-- 重新创建 validate_check_in 函数，添加调试日志
CREATE OR REPLACE FUNCTION validate_check_in()
RETURNS TRIGGER AS $$
DECLARE
  v_member members;
  v_same_class_check_ins INTEGER;
  v_daily_check_ins INTEGER;
BEGIN
  -- 获取会员信息
  SELECT * INTO v_member
  FROM members
  WHERE id = NEW.member_id;

  RAISE NOTICE 'validate_check_in - 会员信息: id=%, membership=%, remaining_classes=%, is_new_member=%', 
    v_member.id, v_member.membership, v_member.remaining_classes, v_member.is_new_member;

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

  RAISE NOTICE 'validate_check_in - 今日有效签到次数: %', v_daily_check_ins;

  -- 设置 is_extra 标志前记录判断条件
  RAISE NOTICE 'validate_check_in - 判断条件: is_new_member=%, membership_type=%, remaining_classes=%, daily_check_ins=%',
    v_member.is_new_member,
    v_member.membership,
    v_member.remaining_classes,
    v_daily_check_ins;

  -- 设置 is_extra 标志
  NEW.is_extra := CASE
    WHEN v_member.is_new_member THEN true
    WHEN v_member.membership_expiry < CURRENT_DATE AND v_member.membership NOT IN ('single_class', 'two_classes', 'ten_classes') THEN true
    WHEN v_member.membership IN ('single_class', 'two_classes', 'ten_classes') AND v_member.remaining_classes = 0 THEN true
    WHEN v_member.membership = 'single_monthly' AND v_daily_check_ins > 0 THEN true
    WHEN v_member.membership = 'double_monthly' AND v_daily_check_ins > 1 THEN true
    ELSE false
  END;

  -- 记录设置结果
  RAISE NOTICE 'validate_check_in - 设置原因: %',
    CASE
      WHEN v_member.is_new_member THEN '新会员'
      WHEN v_member.membership_expiry < CURRENT_DATE AND v_member.membership NOT IN ('single_class', 'two_classes', 'ten_classes') THEN '月卡过期'
      WHEN v_member.membership IN ('single_class', 'two_classes', 'ten_classes') AND v_member.remaining_classes = 0 THEN '课时卡次数用完'
      WHEN v_member.membership = 'single_monthly' AND v_daily_check_ins > 0 THEN '单次月卡超出限制'
      WHEN v_member.membership = 'double_monthly' AND v_daily_check_ins > 1 THEN '双次月卡超出限制'
      ELSE '正常签到'
    END;

  RAISE NOTICE 'validate_check_in - 最终设置 is_extra=%', NEW.is_extra;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 重新创建 process_check_in 函数，添加调试日志
CREATE OR REPLACE FUNCTION process_check_in()
RETURNS TRIGGER AS $$
DECLARE
  v_old_remaining_classes INTEGER;
  v_new_remaining_classes INTEGER;
BEGIN
  -- 记录更新前的课时数
  SELECT remaining_classes INTO v_old_remaining_classes
  FROM members
  WHERE id = NEW.member_id;

  RAISE NOTICE 'process_check_in - 开始处理: member_id=%, is_extra=%, old_remaining_classes=%',
    NEW.member_id, NEW.is_extra, v_old_remaining_classes;

  -- 更新会员信息
  UPDATE members
  SET 
    -- 课时卡会员非额外签到时扣减次数
    remaining_classes = CASE 
      WHEN membership IN ('single_class', 'two_classes', 'ten_classes') 
           AND NOT NEW.is_extra 
      THEN remaining_classes - 1
      ELSE remaining_classes
    END,
    -- 额外签到增加计数
    extra_check_ins = CASE 
      WHEN NEW.is_extra 
      THEN extra_check_ins + 1
      ELSE extra_check_ins
    END,
    -- 更新签到统计
    daily_check_ins = daily_check_ins + 1,
    last_check_in_date = NEW.check_in_date,
    -- 更新新会员状态
    is_new_member = false
  WHERE id = NEW.member_id
  RETURNING remaining_classes INTO v_new_remaining_classes;

  RAISE NOTICE 'process_check_in - 更新完成: new_remaining_classes=%, changed=%',
    v_new_remaining_classes, (v_old_remaining_classes != v_new_remaining_classes);

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMIT; 