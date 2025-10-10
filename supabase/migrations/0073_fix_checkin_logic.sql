BEGIN;

-- 重新创建 validate_check_in 函数
CREATE OR REPLACE FUNCTION validate_check_in()
RETURNS TRIGGER AS $$
DECLARE
  v_member members;
  v_daily_check_ins INTEGER;
BEGIN
  -- 获取会员信息
  SELECT * INTO v_member
  FROM members
  WHERE id = NEW.member_id;

  -- 检查是否已经签到
  SELECT COUNT(*) INTO v_daily_check_ins
  FROM check_ins
  WHERE member_id = NEW.member_id
  AND check_in_date = NEW.check_in_date;

  -- 设置 is_extra 标志
  NEW.is_extra := CASE
    -- 新会员的首次签到标记为额外签到
    WHEN v_member.is_new_member AND v_daily_check_ins = 0 THEN true
    -- 次卡会员且剩余次数为0，标记为额外签到
    WHEN v_member.membership = 'single_class' AND v_member.remaining_classes = 0 THEN true
    -- 月卡会员且当天已有签到，标记为额外签到
    WHEN v_member.membership IN ('single_monthly', 'double_monthly') AND v_daily_check_ins > 0 THEN true
    -- 其他情况不标记为额外签到
    ELSE false
  END;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 重新创建 process_check_in 函数
CREATE OR REPLACE FUNCTION process_check_in()
RETURNS TRIGGER AS $$
BEGIN
  -- 更新会员信息
  UPDATE members
  SET 
    -- 次卡会员非额外签到时扣减次数
    remaining_classes = CASE 
      WHEN membership = 'single_class' AND NEW.is_extra = false 
      THEN remaining_classes - 1
      ELSE remaining_classes
    END,
    -- 额外签到增加计数
    extra_check_ins = CASE 
      WHEN NEW.is_extra = true 
      THEN extra_check_ins + 1
      ELSE extra_check_ins
    END,
    -- 更新签到统计
    daily_check_ins = daily_check_ins + 1,
    last_check_in_date = NEW.check_in_date,
    -- 如果是新会员的首次签到，更新状态
    is_new_member = CASE
      WHEN is_new_member AND NEW.is_extra = true THEN false
      ELSE is_new_member
    END
  WHERE id = NEW.member_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMIT; 