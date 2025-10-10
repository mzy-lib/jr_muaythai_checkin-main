-- 重新创建函数，添加SECURITY DEFINER
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
  -- 函数内容保持不变
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

    -- 记录找到的会员信息
    INSERT INTO debug_logs (function_name, member_id, message, details)
    VALUES (
      'validate_check_in',
      NEW.member_id,
      '找到会员信息',
      jsonb_build_object(
        'member', row_to_json(v_member)
      )
    );

    -- Count daily check-ins (excluding current record and extra check-ins)
    SELECT COUNT(*)
    INTO v_daily_check_ins
    FROM check_ins
    WHERE member_id = NEW.member_id
      AND check_in_date = NEW.check_in_date
      AND id IS DISTINCT FROM NEW.id
      AND NOT is_extra;

    -- 记录每日签到次数
    INSERT INTO debug_logs (function_name, member_id, message, details)
    VALUES (
      'validate_check_in',
      NEW.member_id,
      '统计每日签到次数',
      jsonb_build_object(
        'daily_check_ins', v_daily_check_ins
      )
    );

    -- Check for same class type check-in
    SELECT EXISTS (
      SELECT 1
      FROM check_ins
      WHERE member_id = NEW.member_id
        AND check_in_date = NEW.check_in_date
        AND class_type = NEW.class_type
        AND id IS DISTINCT FROM NEW.id
    ) INTO v_has_same_class_check_in;

    IF v_has_same_class_check_in THEN
      -- 记录重复签到错误
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
      RAISE EXCEPTION '会员 % 在 % 已经签到过 % 课程', NEW.member_id, NEW.check_in_date, NEW.class_type;
    END IF;

    -- Set is_extra based on various conditions
    NEW.is_extra := CASE
      -- New member's first check-in
      WHEN v_member.is_new_member THEN
        TRUE
      -- Monthly membership expired
      WHEN v_member.membership IN ('single_monthly', 'double_monthly')
        AND v_member.membership_expiry < NEW.check_in_date THEN
        TRUE
      -- Single monthly exceeded daily limit
      WHEN v_member.membership = 'single_monthly'
        AND v_daily_check_ins >= 1 THEN
        TRUE
      -- Double monthly exceeded daily limit
      WHEN v_member.membership = 'double_monthly'
        AND v_daily_check_ins >= 2 THEN
        TRUE
      -- Class package with no remaining classes
      WHEN v_member.membership IN ('single_class', 'two_classes', 'ten_classes')
        AND (v_member.remaining_classes IS NULL OR v_member.remaining_classes <= 0) THEN
        TRUE
      -- Other situations
      ELSE
        FALSE
    END;

    -- 记录is_extra的设置结果
    INSERT INTO debug_logs (function_name, member_id, message, details)
    VALUES (
      'validate_check_in',
      NEW.member_id,
      '设置签到类型',
      jsonb_build_object(
        'is_extra', NEW.is_extra,
        'reason', CASE
          WHEN v_member.is_new_member THEN '新会员首次签到'
          WHEN v_member.membership IN ('single_monthly', 'double_monthly')
            AND v_member.membership_expiry < NEW.check_in_date THEN '会员卡已过期'
          WHEN v_member.membership = 'single_monthly'
            AND v_daily_check_ins >= 1 THEN '单次月卡超出每日限制'
          WHEN v_member.membership = 'double_monthly'
            AND v_daily_check_ins >= 2 THEN '双次月卡超出每日限制'
          WHEN v_member.membership IN ('single_class', 'two_classes', 'ten_classes')
            AND (v_member.remaining_classes IS NULL OR v_member.remaining_classes <= 0) THEN '次卡剩余次数不足'
          ELSE '正常签到'
        END
      )
    );

    RETURN NEW;
  EXCEPTION
    WHEN OTHERS THEN
      -- 记录其他未预期的错误
      INSERT INTO debug_logs (function_name, member_id, message, details)
      VALUES (
        'validate_check_in',
        NEW.member_id,
        '发生错误',
        jsonb_build_object(
          'error', SQLERRM,
          'context', row_to_json(NEW)
        )
      );
      RAISE;
  END;
END;
$$;

CREATE OR REPLACE FUNCTION process_check_in()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_old_values RECORD;
  v_new_values RECORD;
BEGIN
  -- 函数开始时记录日志
  INSERT INTO debug_logs (function_name, member_id, message, details)
  VALUES (
    'process_check_in',
    NEW.member_id,
    '开始处理签到',
    jsonb_build_object(
      'check_in_data', row_to_json(NEW)
    )
  );

  BEGIN
    -- Get current member state
    SELECT *
    INTO v_old_values
    FROM members
    WHERE id = NEW.member_id;

    -- 记录更新前的会员状态
    INSERT INTO debug_logs (function_name, member_id, message, details)
    VALUES (
      'process_check_in',
      NEW.member_id,
      '更新前的会员状态',
      jsonb_build_object(
        'member', row_to_json(v_old_values)
      )
    );

    -- Update member information
    UPDATE members
    SET
      remaining_classes = CASE
        WHEN membership IN ('single_class', 'two_classes', 'ten_classes')
          AND remaining_classes > 0
          AND NOT NEW.is_extra
        THEN remaining_classes - 1
        ELSE remaining_classes
      END,
      last_check_in_date = NEW.check_in_date,
      daily_check_ins = CASE
        WHEN last_check_in_date = NEW.check_in_date THEN daily_check_ins + 1
        ELSE 1
      END,
      extra_check_ins = CASE
        WHEN NEW.is_extra THEN extra_check_ins + 1
        ELSE extra_check_ins
      END,
      is_new_member = CASE
        WHEN is_new_member THEN false
        ELSE is_new_member
      END
    WHERE id = NEW.member_id
    RETURNING * INTO v_new_values;

    -- 记录更新后的会员状态
    INSERT INTO debug_logs (function_name, member_id, message, details)
    VALUES (
      'process_check_in',
      NEW.member_id,
      '更新后的会员状态',
      jsonb_build_object(
        'changes', jsonb_build_object(
          'remaining_classes', jsonb_build_object(
            'old', v_old_values.remaining_classes,
            'new', v_new_values.remaining_classes
          ),
          'daily_check_ins', jsonb_build_object(
            'old', v_old_values.daily_check_ins,
            'new', v_new_values.daily_check_ins
          ),
          'extra_check_ins', jsonb_build_object(
            'old', v_old_values.extra_check_ins,
            'new', v_new_values.extra_check_ins
          ),
          'is_new_member', jsonb_build_object(
            'old', v_old_values.is_new_member,
            'new', v_new_values.is_new_member
          )
        )
      )
    );

    RETURN NEW;
  EXCEPTION
    WHEN OTHERS THEN
      -- 记录其他未预期的错误
      INSERT INTO debug_logs (function_name, member_id, message, details)
      VALUES (
        'process_check_in',
        NEW.member_id,
        '发生错误',
        jsonb_build_object(
          'error', SQLERRM,
          'context', row_to_json(NEW)
        )
      );
      RAISE;
  END;
END;
$$;

-- 授予必要的权限
GRANT ALL ON debug_logs TO postgres, authenticated, anon;
GRANT ALL ON debug_logs_id_seq TO postgres, authenticated, anon;

-- 删除已存在的触发器
DROP TRIGGER IF EXISTS validate_check_in_trigger ON check_ins;
DROP TRIGGER IF EXISTS process_check_in_trigger ON check_ins;

-- 重新创建触发器
CREATE TRIGGER validate_check_in_trigger
  BEFORE INSERT ON check_ins
  FOR EACH ROW
  EXECUTE FUNCTION validate_check_in();

CREATE TRIGGER process_check_in_trigger
  AFTER INSERT ON check_ins
  FOR EACH ROW
  EXECUTE FUNCTION process_check_in(); 