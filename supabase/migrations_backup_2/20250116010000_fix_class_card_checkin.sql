-- 修复课时卡签到逻辑
-- 1. 充分利用数据库特性
-- 2. 简化判断逻辑
-- 3. 确保数据一致性

-- 重新创建validate_check_in函数
CREATE OR REPLACE FUNCTION public.validate_check_in()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
  v_member RECORD;
  v_daily_check_ins integer;
  v_has_same_class_check_in boolean;
BEGIN
  -- 锁定会员记录
  SELECT *
  INTO v_member
  FROM members
  WHERE id = NEW.member_id
  FOR UPDATE;  -- 使用行级锁确保并发安全

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member not found';
  END IF;

  -- 获取当日非额外签到次数
  SELECT COUNT(*)
  INTO v_daily_check_ins
  FROM check_ins
  WHERE member_id = NEW.member_id
    AND check_in_date = NEW.check_in_date
    AND id IS DISTINCT FROM NEW.id
    AND NOT is_extra;

  -- 检查同一时段重复签到
  SELECT EXISTS (
    SELECT 1
    FROM check_ins
    WHERE member_id = NEW.member_id
      AND check_in_date = NEW.check_in_date
      AND class_type = NEW.class_type
      AND id IS DISTINCT FROM NEW.id
  ) INTO v_has_same_class_check_in;

  IF v_has_same_class_check_in THEN
    RAISE EXCEPTION '今天已经在这个时段签到过了\nAlready checked in for this class type today';
  END IF;

  -- 设置额外签到标记
  NEW.is_extra := CASE
    -- 新会员
    WHEN v_member.is_new_member THEN true
    -- 会员卡过期
    WHEN v_member.membership_expiry < NEW.check_in_date THEN true
    -- 课时卡且剩余次数为0
    WHEN v_member.membership IN ('single_class', 'two_classes', 'ten_classes') 
         AND v_member.remaining_classes <= 0 THEN true
    -- 单次月卡超出每日限制
    WHEN v_member.membership = 'single_monthly' 
         AND v_daily_check_ins >= 1 THEN true
    -- 双次月卡超出每日限制
    WHEN v_member.membership = 'double_monthly' 
         AND v_daily_check_ins >= 2 THEN true
    -- 其他情况为正常签到
    ELSE false
  END;

  -- 记录验证结果
  INSERT INTO debug_logs (
    function_name,
    member_id,
    message,
    details
  ) VALUES (
    'validate_check_in',
    NEW.member_id,
    CASE WHEN NEW.is_extra THEN '额外签到' ELSE '正常签到' END,
    jsonb_build_object(
      'check_in_date', NEW.check_in_date,
      'class_type', NEW.class_type,
      'is_extra', NEW.is_extra,
      'membership', v_member.membership,
      'membership_expiry', v_member.membership_expiry,
      'remaining_classes', v_member.remaining_classes,
      'daily_check_ins', v_daily_check_ins,
      'reason', CASE
        WHEN v_member.is_new_member THEN '新会员'
        WHEN v_member.membership_expiry < NEW.check_in_date THEN '会员卡已过期'
        WHEN v_member.membership IN ('single_class', 'two_classes', 'ten_classes') 
             AND v_member.remaining_classes <= 0 THEN '课时不足'
        WHEN v_member.membership = 'single_monthly' AND v_daily_check_ins >= 1 THEN '超出单次月卡每日限制'
        WHEN v_member.membership = 'double_monthly' AND v_daily_check_ins >= 2 THEN '超出双次月卡每日限制'
        ELSE '正常签到'
      END
    )
  );

  RETURN NEW;
END;
$function$;

-- 重新创建process_check_in函数
CREATE OR REPLACE FUNCTION public.process_check_in()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
    v_member members;
    v_daily_check_ins integer;
    v_extra_check_ins integer;
    v_remaining_classes integer;
BEGIN
    -- 锁定会员记录
    SELECT * INTO v_member
    FROM members
    WHERE id = NEW.member_id
    FOR NO KEY UPDATE;  -- 使用NO KEY UPDATE避免不必要的锁竞争

    -- 更新会员状态
    UPDATE members 
    SET 
        daily_check_ins = CASE 
            WHEN last_check_in_date = NEW.check_in_date THEN daily_check_ins + 1 
            ELSE 1 
        END,
        extra_check_ins = CASE 
            WHEN NEW.is_extra THEN extra_check_ins + 1 
            ELSE extra_check_ins 
        END,
        remaining_classes = CASE 
            WHEN NOT NEW.is_extra AND membership IN ('single_class', 'two_classes', 'ten_classes') 
            THEN remaining_classes - 1 
            ELSE remaining_classes 
        END,
        last_check_in_date = NEW.check_in_date
    WHERE id = NEW.member_id
    RETURNING 
        daily_check_ins,
        extra_check_ins,
        remaining_classes
    INTO 
        v_daily_check_ins,
        v_extra_check_ins,
        v_remaining_classes;

    -- 记录处理结果
    INSERT INTO debug_logs (
        function_name, 
        message, 
        member_id, 
        details
    ) VALUES (
        'process_check_in',
        '处理完成',
        NEW.member_id,
        jsonb_build_object(
            'check_in_date', NEW.check_in_date,
            'class_type', NEW.class_type,
            'is_extra', NEW.is_extra,
            'original_remaining_classes', v_member.remaining_classes,
            'new_remaining_classes', v_remaining_classes,
            'was_deducted', v_remaining_classes != v_member.remaining_classes,
            'new_extra_check_ins', v_extra_check_ins,
            'daily_check_ins', v_daily_check_ins
        )
    );

    RETURN NULL;
END;
$function$;

-- 删除现有触发器
DROP TRIGGER IF EXISTS check_in_validation_trigger ON check_ins;
DROP TRIGGER IF EXISTS process_check_in_trigger ON check_ins;

-- 创建新的触发器
CREATE TRIGGER check_in_validation_trigger
  BEFORE INSERT ON check_ins
  FOR EACH ROW
  EXECUTE FUNCTION validate_check_in();

CREATE TRIGGER process_check_in_trigger
  AFTER INSERT ON check_ins
  FOR EACH ROW
  EXECUTE FUNCTION process_check_in();

-- 添加注释
COMMENT ON FUNCTION validate_check_in() IS 
'签到验证函数：
- 使用行级锁确保并发安全
- 基于remaining_classes判断额外签到
- 简化验证逻辑
- 记录详细日志';

COMMENT ON FUNCTION process_check_in() IS 
'签到处理函数：
- 使用NO KEY UPDATE锁定会员记录
- 原子性更新会员状态
- 记录状态变更日志'; 