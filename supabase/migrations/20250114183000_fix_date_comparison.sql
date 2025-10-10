CREATE OR REPLACE FUNCTION validate_check_in()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_member RECORD;
  v_daily_check_ins integer;
  v_has_same_class_check_in boolean;
BEGIN
  -- 函数开始时记录日志
  INSERT INTO debug_logs (function_name, member_id, message, details)
  VALUES (
    'validate_check_in',
    NEW.member_id,
    '开始验证签到',
    jsonb_build_object(
      'check_in_data', row_to_json(NEW)
    )
  );

  BEGIN
    -- Get member details
    SELECT *
    INTO v_member
    FROM members
    WHERE id = NEW.member_id;

    IF NOT FOUND THEN
      -- 记录未找到会员的错误
      INSERT INTO debug_logs (function_name, member_id, message, details)
      VALUES (
        'validate_check_in',
        NEW.member_id,
        '未找到会员',
        jsonb_build_object(
          'error', 'Member not found'
        )
      );
      RAISE EXCEPTION '未找到会员ID为 % 的记录', NEW.member_id;
    END IF;

    -- 记录会员信息
    INSERT INTO debug_logs (function_name, member_id, message, details)
    VALUES (
      'validate_check_in',
      NEW.member_id,
      '获取到会员信息',
      jsonb_build_object(
        'member_data', row_to_json(v_member)
      )
    );

    -- Get daily check-ins count for the member (excluding current record and extra check-ins)
    SELECT COUNT(*)
    INTO v_daily_check_ins
    FROM check_ins
    WHERE member_id = NEW.member_id
      AND check_in_date = NEW.check_in_date
      AND id IS DISTINCT FROM NEW.id  -- 排除当前记录
      AND NOT is_extra;  -- 只计算非额外签到

    -- 记录签到统计
    INSERT INTO debug_logs (function_name, member_id, message, details)
    VALUES (
      'validate_check_in',
      NEW.member_id,
      '当日签到统计',
      jsonb_build_object(
        'daily_check_ins', v_daily_check_ins
      )
    );

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
      INSERT INTO debug_logs (function_name, member_id, message, details)
      VALUES (
        'validate_check_in',
        NEW.member_id,
        '检测到重复签到',
        jsonb_build_object(
          'class_type', NEW.class_type,
          'check_in_date', NEW.check_in_date
        )
      );
      RAISE EXCEPTION '今天已经在该时段签到过了';
    END IF;

    -- Set is_extra based on different scenarios
    NEW.is_extra := CASE
      -- New member: first check-in is extra
      WHEN v_member.is_new_member THEN 
        true
      
      -- Monthly membership scenarios
      WHEN v_member.membership = 'single_monthly' THEN
        CASE
          -- Expired membership
          WHEN DATE(v_member.membership_expiry) < NEW.check_in_date THEN true
          -- Over daily limit (1 class per day)
          WHEN v_daily_check_ins >= 1 THEN true
          ELSE false
        END
      WHEN v_member.membership = 'double_monthly' THEN
        CASE
          -- Expired membership
          WHEN DATE(v_member.membership_expiry) < NEW.check_in_date THEN true
          -- Over daily limit (2 classes per day)
          WHEN v_daily_check_ins >= 2 THEN true
          ELSE false
        END
        
      -- Class package scenarios
      WHEN v_member.membership IN ('single_class', 'two_classes', 'ten_classes') THEN
        CASE
          -- No remaining classes
          WHEN v_member.remaining_classes <= 0 THEN true
          ELSE false
        END
        
      -- No valid membership
      ELSE true
    END;

    -- 记录签到结果
    INSERT INTO debug_logs (function_name, member_id, message, details)
    VALUES (
      'validate_check_in',
      NEW.member_id,
      '签到验证完成',
      jsonb_build_object(
        'is_extra', NEW.is_extra,
        'reason', CASE
          WHEN v_member.is_new_member THEN '新会员首次签到'
          WHEN v_member.membership = 'single_monthly' AND DATE(v_member.membership_expiry) < NEW.check_in_date THEN '单次月卡已过期'
          WHEN v_member.membership = 'single_monthly' AND v_daily_check_ins >= 1 THEN '单次月卡当日签到次数已达上限'
          WHEN v_member.membership = 'double_monthly' AND DATE(v_member.membership_expiry) < NEW.check_in_date THEN '双次月卡已过期'
          WHEN v_member.membership = 'double_monthly' AND v_daily_check_ins >= 2 THEN '双次月卡当日签到次数已达上限'
          WHEN v_member.membership IN ('single_class', 'two_classes', 'ten_classes') AND v_member.remaining_classes <= 0 THEN '次卡剩余次数不足'
          WHEN v_member.membership IS NULL THEN '无有效会员卡'
          ELSE '正常签到'
        END
      )
    );

    RETURN NEW;
  EXCEPTION
    WHEN OTHERS THEN
      -- 记录其他错误
      INSERT INTO debug_logs (function_name, member_id, message, details)
      VALUES (
        'validate_check_in',
        NEW.member_id,
        '发生错误',
        jsonb_build_object(
          'error', SQLERRM,
          'state', SQLSTATE
        )
      );
      RAISE;
  END;
END;
$$; 