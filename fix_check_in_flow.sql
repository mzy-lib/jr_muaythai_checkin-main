-- 添加日志记录到trigger_deduct_sessions函数，并修复会员卡与签到的关联问题
CREATE OR REPLACE FUNCTION trigger_deduct_sessions()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
  -- 记录触发器执行开始
  INSERT INTO debug_logs (function_name, message, details)
  VALUES ('trigger_deduct_sessions', '触发器执行开始',
    jsonb_build_object(
      'check_in_id', NEW.id,
      'member_id', NEW.member_id,
      'card_id', NEW.card_id,
      'is_extra', NEW.is_extra,
      'class_type', NEW.class_type
    )
  );

  -- 只有非额外签到才扣除课时
  IF NOT NEW.is_extra AND NEW.card_id IS NOT NULL THEN
    -- 传递is_private参数
    PERFORM deduct_membership_sessions(NEW.card_id, NEW.class_type::TEXT, NEW.is_private);
    
    -- 记录扣除课时结果
    INSERT INTO debug_logs (function_name, message, details)
    VALUES ('trigger_deduct_sessions', '扣除课时完成',
      jsonb_build_object(
        'check_in_id', NEW.id,
        'member_id', NEW.member_id,
        'card_id', NEW.card_id,
        'class_type', NEW.class_type,
        'is_private', NEW.is_private
      )
    );
  ELSE
    -- 记录未扣除课时原因
    INSERT INTO debug_logs (function_name, message, details)
    VALUES ('trigger_deduct_sessions', '未扣除课时',
      jsonb_build_object(
        'reason', CASE 
                    WHEN NEW.is_extra THEN '额外签到不扣除课时'
                    WHEN NEW.card_id IS NULL THEN '未指定会员卡'
                    ELSE '未知原因'
                  END,
        'check_in_id', NEW.id,
        'member_id', NEW.member_id,
        'is_extra', NEW.is_extra,
        'card_id', NEW.card_id
      )
    );
  END IF;

  RETURN NULL;
END;
$function$;

-- 重新授予函数执行权限
GRANT EXECUTE ON FUNCTION trigger_deduct_sessions() TO anon, authenticated, service_role;

-- 创建一个函数用于在签到时自动关联会员卡
CREATE OR REPLACE FUNCTION find_valid_card_for_checkin()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
  v_card_id UUID;
  v_card_type TEXT;
  v_class_type TEXT := NEW.class_type;
  v_is_private BOOLEAN := NEW.is_private;
BEGIN
  -- 如果已经指定了会员卡，则不需要自动查找
  IF NEW.card_id IS NOT NULL THEN
    RETURN NEW;
  END IF;
  
  -- 如果是额外签到，则不需要关联会员卡
  IF NEW.is_extra THEN
    RETURN NEW;
  END IF;
  
  -- 记录开始查找会员卡
  INSERT INTO debug_logs (function_name, message, details)
  VALUES ('find_valid_card_for_checkin', '开始查找有效会员卡',
    jsonb_build_object(
      'member_id', NEW.member_id,
      'class_type', v_class_type,
      'is_private', v_is_private
    )
  );
  
  -- 根据课程类型确定需要查找的卡类型
  IF v_is_private THEN
    v_card_type := 'private';
  ELSE
    v_card_type := 'class';  -- 或者 'group'，取决于实际数据
  END IF;
  
  -- 查找有效的会员卡
  -- 优先查找课时卡，其次是月卡
  SELECT id INTO v_card_id
  FROM membership_cards
  WHERE member_id = NEW.member_id
    AND (
      -- 对于私教课
      (v_is_private AND card_type = 'private' AND 
       (remaining_private_sessions IS NULL OR remaining_private_sessions > 0))
      OR
      -- 对于团课
      (NOT v_is_private AND (card_type = 'class' OR card_type = 'group') AND 
       (card_category = 'session' OR card_category = 'group') AND
       (remaining_group_sessions IS NULL OR remaining_group_sessions > 0))
    )
    AND (valid_until IS NULL OR valid_until >= NEW.check_in_date)
  ORDER BY 
    -- 优先使用课时卡
    CASE WHEN card_category = 'session' OR card_category = 'group' THEN 0 ELSE 1 END,
    -- 优先使用即将过期的卡
    CASE WHEN valid_until IS NOT NULL THEN valid_until ELSE '9999-12-31'::DATE END
  LIMIT 1;
  
  -- 如果找到有效会员卡，则关联到签到记录
  IF v_card_id IS NOT NULL THEN
    NEW.card_id := v_card_id;
    
    -- 记录找到的会员卡
    INSERT INTO debug_logs (function_name, message, details)
    VALUES ('find_valid_card_for_checkin', '找到有效会员卡',
      jsonb_build_object(
        'member_id', NEW.member_id,
        'card_id', v_card_id
      )
    );
  ELSE
    -- 记录未找到有效会员卡
    INSERT INTO debug_logs (function_name, message, details)
    VALUES ('find_valid_card_for_checkin', '未找到有效会员卡',
      jsonb_build_object(
        'member_id', NEW.member_id,
        'class_type', v_class_type,
        'is_private', v_is_private
      )
    );
  END IF;
  
  RETURN NEW;
END;
$function$;

-- 授予函数执行权限
GRANT EXECUTE ON FUNCTION find_valid_card_for_checkin() TO anon, authenticated, service_role;

-- 创建触发器，在插入签到记录前自动关联会员卡
DROP TRIGGER IF EXISTS find_valid_card_trigger ON check_ins;
CREATE TRIGGER find_valid_card_trigger
BEFORE INSERT ON check_ins
FOR EACH ROW
EXECUTE FUNCTION find_valid_card_for_checkin(); 