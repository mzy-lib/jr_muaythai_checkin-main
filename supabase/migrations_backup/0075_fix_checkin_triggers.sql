BEGIN;

-- 重新创建 validate_check_in 函数
-- 用于验证签到请求并设置额外签到标志
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

  -- 检查是否已经签到
  -- 同一会员在同一天的同一时段只能签到一次
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
  -- 单次月卡每日限1次，双次月卡每日限2次
  -- 超出限制的签到将被标记为额外签到
  SELECT COUNT(*) INTO v_daily_check_ins
  FROM check_ins
  WHERE member_id = NEW.member_id
  AND check_in_date = NEW.check_in_date
  AND is_extra = false;

  -- 设置 is_extra 标志
  -- 注意：以下条件互斥，会员卡类型唯一
  NEW.is_extra := CASE
    -- 1. 新会员：还未购买任何会员卡的用户
    WHEN v_member.is_new_member THEN true
    -- 2. 会员卡过期：过期后需要手动续卡
    -- 注：会员卡有效期最后一天仍可正常签到
    WHEN v_member.membership_expiry < CURRENT_DATE THEN true
    -- 3. 课时卡且次数用完：需要手动购买新的课时卡
    WHEN v_member.membership IN ('single_class', 'two_classes', 'ten_classes') 
         AND v_member.remaining_classes = 0 THEN true
    -- 4. 单次月卡超出每日1次限制
    WHEN v_member.membership = 'single_monthly' 
         AND v_daily_check_ins > 0 THEN true
    -- 5. 双次月卡超出每日2次限制
    WHEN v_member.membership = 'double_monthly' 
         AND v_daily_check_ins > 1 THEN true
    -- 6. 其他情况：正常签到
    ELSE false
  END;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 重新创建 process_check_in 函数
-- 用于处理签到后的会员信息更新
CREATE OR REPLACE FUNCTION process_check_in()
RETURNS TRIGGER AS $$
BEGIN
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
    -- 更新新会员状态：首次签到后不再是新会员
    is_new_member = CASE
      WHEN is_new_member THEN false
      ELSE is_new_member
    END
  WHERE id = NEW.member_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMIT; 