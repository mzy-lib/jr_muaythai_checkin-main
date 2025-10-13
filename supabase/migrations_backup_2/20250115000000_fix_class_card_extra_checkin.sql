-- 修复次卡会员的额外签到判断逻辑
CREATE OR REPLACE FUNCTION public.validate_check_in()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
  v_member RECORD;
  v_daily_check_ins integer;
  v_has_same_class_check_in boolean;
  v_processed boolean;
BEGIN
  -- Check if this check-in has already been processed
  SELECT EXISTS (
    SELECT 1 
    FROM debug_logs 
    WHERE member_id = NEW.member_id 
      AND created_at >= CURRENT_TIMESTAMP - interval '1 second'
      AND function_name = 'validate_check_in'
  ) INTO v_processed;

  IF v_processed THEN
    -- Skip validation if already processed
    RETURN NEW;
  END IF;

  -- Get member details with lock
  SELECT *
  INTO v_member
  FROM members
  WHERE id = NEW.member_id
  FOR UPDATE;  -- Lock the row to prevent concurrent modifications

  -- Check if member exists
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member not found';
  END IF;

  -- Get daily check-ins count for the member (excluding current record)
  SELECT COUNT(*)
  INTO v_daily_check_ins
  FROM check_ins
  WHERE member_id = NEW.member_id
    AND check_in_date = NEW.check_in_date
    AND id IS DISTINCT FROM NEW.id  -- 排除当前记录
    AND NOT is_extra;  -- 只计算非额外签到

  -- Set is_extra flag
  NEW.is_extra := CASE
    -- 1. 新会员：还未购买任何会员卡的用户
    WHEN v_member.is_new_member THEN true
    -- 2. 会员卡过期：过期后需要手动续卡
    WHEN v_member.membership_expiry < CURRENT_DATE THEN true
    -- 3. 课时卡且次数用完：需要手动购买新的课时卡
    WHEN v_member.membership IN ('single_class', 'two_classes', 'ten_classes') 
         AND v_member.remaining_classes <= 0 THEN true
    -- 4. 单次月卡超出每日1次限制
    WHEN v_member.membership = 'single_monthly' 
         AND v_daily_check_ins > 0 THEN true
    -- 5. 双次月卡超出每日2次限制
    WHEN v_member.membership = 'double_monthly' 
         AND v_daily_check_ins > 1 THEN true
    -- 6. 其他情况：正常签到
    ELSE false
  END;

  -- Log validation result
  INSERT INTO debug_logs (
    function_name,
    member_id,
    message,
    details
  ) VALUES (
    'validate_check_in',
    NEW.member_id,
    CASE
      WHEN NEW.is_extra THEN '额外签到'
      ELSE '正常签到'
    END,
    jsonb_build_object(
      'membership', v_member.membership,
      'remaining_classes', v_member.remaining_classes,
      'daily_check_ins', v_daily_check_ins,
      'is_extra', NEW.is_extra
    )
  );

  RETURN NEW;
END;
$function$;

-- Drop existing trigger
DROP TRIGGER IF EXISTS check_in_validation_trigger ON check_ins;

-- Create new trigger
CREATE TRIGGER check_in_validation_trigger
  BEFORE INSERT ON check_ins
  FOR EACH ROW
  EXECUTE FUNCTION validate_check_in();

-- Add comment
COMMENT ON FUNCTION validate_check_in() IS 
'Enhanced check-in validation with:
- Fixed class-based membership extra check-in logic
- Proper counting of total normal check-ins
- Clear validation logging
- Atomic transaction handling';

-- 更新签到处理函数
CREATE OR REPLACE FUNCTION public.process_check_in()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
    v_member members;
    v_daily_check_ins integer;
    v_extra_check_ins integer;
    v_remaining_classes integer;
    v_should_mark_extra boolean;
BEGIN
    -- 更精确的防重复检查
    IF EXISTS (
        SELECT 1 
        FROM debug_logs 
        WHERE member_id = NEW.member_id 
            AND created_at >= CURRENT_TIMESTAMP - interval '1 second'
            AND function_name = 'process_check_in'
            AND (details->>'check_in_date')::date = NEW.check_in_date
            AND details->>'class_type' = NEW.class_type::text
    ) THEN
        RETURN NULL;
    END IF;

    -- 锁定会员记录
    SELECT * INTO v_member
    FROM members
    WHERE id = NEW.member_id
    FOR NO KEY UPDATE;

    -- 判断是否需要标记为额外签到
    -- 对于课时卡，如果这次签到会导致剩余次数变为负数，则标记为额外签到
    v_should_mark_extra := 
        v_member.membership IN ('single_class', 'two_classes', 'ten_classes') AND
        NOT NEW.is_extra AND
        v_member.remaining_classes <= 0;

    IF v_should_mark_extra THEN
        -- 更新check_ins记录为额外签到
        NEW.is_extra := true;
    END IF;

    -- 更新会员状态
    UPDATE members 
    SET 
        daily_check_ins = CASE 
            WHEN last_check_in_date = NEW.check_in_date 
            THEN daily_check_ins + 1 
            ELSE 1 
        END,
        extra_check_ins = CASE 
            WHEN NEW.is_extra OR v_should_mark_extra
            THEN extra_check_ins + 1 
            ELSE extra_check_ins 
        END,
        remaining_classes = CASE 
            WHEN NOT (NEW.is_extra OR v_should_mark_extra) AND remaining_classes > 0 
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

    -- 记录处理完成
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
            'should_mark_extra', v_should_mark_extra,
            'was_deducted', v_remaining_classes != v_member.remaining_classes,
            'new_extra_check_ins', v_extra_check_ins,
            'new_remaining_classes', v_remaining_classes,
            'daily_normal_check_ins', v_daily_check_ins
        )
    );

    RETURN NEW;
END;
$function$;

-- Drop existing trigger
DROP TRIGGER IF EXISTS process_check_in_trigger ON check_ins;

-- Create new trigger
CREATE TRIGGER process_check_in_trigger
  AFTER INSERT ON check_ins
  FOR EACH ROW
  EXECUTE FUNCTION process_check_in(); 