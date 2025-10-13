-- 更新与会员卡类型相关的验证函数
-- 此脚本将更新数据库函数，使其适应新的会员卡类型标准

/*
本次更新主要对以下函数进行了改进:

1. check_member_exists函数
- 添加了详细的日志记录
- 返回更多会员信息
- 使用统一的命名规范

2. validate_check_in函数
- 统一使用中文错误提示
- 优化了验证逻辑流程
- 添加了更详细的日志记录
- 统一使用'团课'/'私教课'命名
- 改进了卡类型匹配逻辑
- 添加了剩余课时检查

3. check_card_validity函数
- 统一使用小写的数据类型名称
- 统一使用TRUE/FALSE的小写形式
- 统一使用'团课'/'私教课'命名
- 优化了验证逻辑
- 添加了更详细的日志记录
- 改进了错误处理

4. check_duplicate_check_in函数
- 统一使用小写的数据类型名称
- 统一使用TRUE/FALSE的小写形式
- 统一错误消息格式
- 添加了对NULL时间段的处理
- 改进了课程类型转换和验证
- 简化了重复签到检查逻辑
- 添加了更详细的日志记录

5. deduct_membership_sessions函数
- 统一使用小写的数据类型名称
- 统一使用TRUE/FALSE的小写形式
- 统一使用'团课'/'私教课'命名
- 移除了过期检查(由validate_check_in函数处理)
- 简化了课程类型判断
- 统一了扣除课时的逻辑
- 改进了错误处理
- 添加了更详细的日志记录

6. handle_check_in函数
- 统一使用小写的数据类型名称
- 统一使用TRUE/FALSE的小写形式
- 统一参数顺序和默认值
- 添加了开始处理的日志
- 改进了课程类型转换和验证
- 使用check_member_exists函数检查会员
- 简化了重复签到检查
- 改进了会员卡验证流程
- 优化了课时扣除逻辑
- 添加了更详细的日志记录
- 统一了返回格式

主要改进内容:
1. 统一命名规范
- 使用小写的数据类型名称
- 统一使用TRUE/FALSE的小写形式
- 统一使用'团课'/'私教课'命名
- 统一错误消息格式
- 统一函数参数顺序和默认值

2. 优化验证逻辑
- 改进了课程类型转换和验证
- 简化了重复签到检查
- 改进了会员卡验证流程
- 优化了课时扣除逻辑
- 添加了更多验证检查

3. 改进日志记录
- 添加了更详细的日志信息
- 统一了日志格式和内容
- 记录了完整的处理过程
- 添加了错误日志记录

4. 优化返回结果
- 统一了返回格式
- 简化了返回信息
- 改进了错误处理
- 移除了冗余信息

5. 代码结构优化
- 简化了函数逻辑
- 移除了重复代码
- 改进了错误处理
- 添加了更多注释
*/

-- 记录迁移开始
INSERT INTO migration_logs (migration_name, description)
VALUES ('20250401000003_update_card_validation_functions', '更新会员卡验证函数开始');

-- 修改check_card_validity函数
CREATE OR REPLACE FUNCTION check_card_validity(
  p_card_id uuid,
  p_member_id uuid,
  p_class_type text,
  p_check_in_date date,
  p_trainer_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
AS $function$
DECLARE
  v_card RECORD;
  v_class_type class_type;
  v_is_private boolean;
  v_result jsonb;
  v_trainer_type text;
BEGIN
  -- 记录开始验证
  PERFORM log_debug(
    'check_card_validity',
    '开始验证会员卡',
    jsonb_build_object(
      'card_id', p_card_id,
      'member_id', p_member_id,
      'class_type', p_class_type,
      'check_in_date', p_check_in_date,
      'trainer_id', p_trainer_id
    )
  );

  -- 转换课程类型
  BEGIN
    v_class_type := p_class_type::class_type;
    v_is_private := (v_class_type = 'private');
  EXCEPTION WHEN OTHERS THEN
    PERFORM log_debug(
      'check_card_validity',
      '无效的课程类型',
      jsonb_build_object(
        'class_type', p_class_type,
        'error', SQLERRM
      )
    );
    RETURN jsonb_build_object(
      'is_valid', false,
      'reason', '无效的课程类型',
      'details', jsonb_build_object(
        'class_type', p_class_type,
        'error', SQLERRM
      )
    );
  END;

  -- 获取会员卡信息
  SELECT *
  INTO v_card
  FROM membership_cards
  WHERE id = p_card_id
  FOR UPDATE;

  -- 检查会员卡是否存在
  IF NOT FOUND THEN
    PERFORM log_debug(
      'check_card_validity',
      '会员卡不存在',
      jsonb_build_object(
        'card_id', p_card_id
      )
    );
    RETURN jsonb_build_object(
      'is_valid', false,
      'reason', '会员卡不存在'
    );
  END IF;

  -- 检查会员卡是否属于该会员
  IF v_card.member_id != p_member_id THEN
    PERFORM log_debug(
      'check_card_validity',
      '会员卡不属于该会员',
      jsonb_build_object(
        'card_id', p_card_id,
        'card_member_id', v_card.member_id,
        'check_in_member_id', p_member_id
      )
    );
    RETURN jsonb_build_object(
      'is_valid', false,
      'reason', '会员卡不属于该会员',
      'details', jsonb_build_object(
        'card_member_id', v_card.member_id,
        'check_in_member_id', p_member_id
      )
    );
  END IF;

  -- 检查会员卡是否过期
  IF v_card.valid_until IS NOT NULL AND v_card.valid_until < p_check_in_date THEN
    PERFORM log_debug(
      'check_card_validity',
      '会员卡已过期',
      jsonb_build_object(
        'card_id', p_card_id,
        'valid_until', v_card.valid_until,
        'check_in_date', p_check_in_date
      )
    );
    RETURN jsonb_build_object(
      'is_valid', false,
      'reason', '会员卡已过期',
      'details', jsonb_build_object(
        'valid_until', v_card.valid_until,
        'check_in_date', p_check_in_date
      )
    );
  END IF;

  -- 检查卡类型是否匹配课程类型
  IF (v_card.card_type = '团课' AND v_is_private) OR
     (v_card.card_type = '私教课' AND NOT v_is_private) THEN
    PERFORM log_debug(
      'check_card_validity',
      '卡类型与课程类型不匹配',
      jsonb_build_object(
        'card_id', p_card_id,
        'card_type', v_card.card_type,
        'class_type', v_class_type,
        'is_private', v_is_private
      )
    );
    RETURN jsonb_build_object(
      'is_valid', false,
      'reason', '卡类型与课程类型不匹配',
      'details', jsonb_build_object(
        'card_type', v_card.card_type,
        'class_type', v_class_type,
        'is_private', v_is_private
      )
    );
  END IF;

  -- 检查教练等级是否匹配（仅私教课）
  IF v_is_private AND p_trainer_id IS NOT NULL THEN
    -- 获取教练等级
    SELECT type INTO v_trainer_type FROM trainers WHERE id = p_trainer_id;
    
    IF v_trainer_type != v_card.trainer_type THEN
      PERFORM log_debug(
        'check_card_validity',
        '教练等级与会员卡不匹配',
        jsonb_build_object(
          'card_id', p_card_id,
          'card_trainer_type', v_card.trainer_type,
          'trainer_id', p_trainer_id,
          'trainer_type', v_trainer_type
        )
      );
      RETURN jsonb_build_object(
        'is_valid', false,
        'reason', '教练等级与会员卡不匹配',
        'details', jsonb_build_object(
          'card_trainer_type', v_card.trainer_type,
          'trainer_type', v_trainer_type
        )
      );
    END IF;
  END IF;

  -- 检查剩余课时
  IF v_is_private AND v_card.remaining_private_sessions <= 0 THEN
    PERFORM log_debug(
      'check_card_validity',
      '私教课时不足',
      jsonb_build_object(
        'card_id', p_card_id,
        'remaining_sessions', v_card.remaining_private_sessions
      )
    );
    RETURN jsonb_build_object(
      'is_valid', false,
      'reason', '私教课时不足',
      'details', jsonb_build_object(
        'remaining_sessions', v_card.remaining_private_sessions
      )
    );
  ELSIF NOT v_is_private AND v_card.remaining_group_sessions <= 0 THEN
    PERFORM log_debug(
      'check_card_validity',
      '团课课时不足',
      jsonb_build_object(
        'card_id', p_card_id,
        'remaining_sessions', v_card.remaining_group_sessions
      )
    );
    RETURN jsonb_build_object(
      'is_valid', false,
      'reason', '团课课时不足',
      'details', jsonb_build_object(
        'remaining_sessions', v_card.remaining_group_sessions
      )
    );
  END IF;

  -- 会员卡验证通过
  PERFORM log_debug(
    'check_card_validity',
    '会员卡验证通过',
    jsonb_build_object(
      'card_id', p_card_id,
      'card_type', v_card.card_type,
      'valid_until', v_card.valid_until,
      'remaining_group_sessions', v_card.remaining_group_sessions,
      'remaining_private_sessions', v_card.remaining_private_sessions
    )
  );

  RETURN jsonb_build_object(
    'is_valid', true,
    'card_info', jsonb_build_object(
      'id', v_card.id,
      'member_id', v_card.member_id,
      'card_type', v_card.card_type,
      'valid_until', v_card.valid_until,
      'remaining_group_sessions', v_card.remaining_group_sessions,
      'remaining_private_sessions', v_card.remaining_private_sessions
    )
  );
END;
$function$;

-- 更新会员卡有效性详细检查函数
CREATE OR REPLACE FUNCTION check_card_validity_detailed(
  p_card_id UUID,
  p_member_id UUID,
  p_class_type TEXT,
  p_check_in_date DATE
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_card RECORD;
BEGIN
  -- 获取会员卡信息
  SELECT * INTO v_card FROM membership_cards WHERE id = p_card_id;
  
  -- 检查会员卡是否存在
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'is_valid', FALSE,
      'reason', '会员卡不存在',
      'details', jsonb_build_object('card_id', p_card_id)
    );
  END IF;
  
  -- 检查会员卡是否属于该会员
  IF v_card.member_id != p_member_id THEN
    RETURN jsonb_build_object(
      'is_valid', FALSE,
      'reason', '会员卡不属于该会员',
      'details', jsonb_build_object(
        'card_member_id', v_card.member_id,
        'requested_member_id', p_member_id
      )
    );
  END IF;
  
  -- 检查会员卡是否过期
  IF v_card.valid_until IS NOT NULL AND v_card.valid_until < p_check_in_date THEN
    RETURN jsonb_build_object(
      'is_valid', FALSE,
      'reason', '会员卡已过期',
      'details', jsonb_build_object(
        'valid_until', v_card.valid_until,
        'check_in_date', p_check_in_date
      )
    );
  END IF;
  
  -- 检查卡类型是否匹配课程类型
  IF (v_card.card_type = '团课' AND p_class_type = 'private') OR 
     (v_card.card_type = '私教课' AND p_class_type != 'private') THEN
    RETURN jsonb_build_object(
      'is_valid', FALSE,
      'reason', '卡类型不匹配课程类型',
      'details', jsonb_build_object(
        'card_type', v_card.card_type,
        'class_type', p_class_type
      )
    );
  END IF;
  
  -- 检查团课课时卡课时是否足够
  IF v_card.card_type = '团课' AND v_card.card_category = '课时卡' AND
     (v_card.remaining_group_sessions IS NULL OR v_card.remaining_group_sessions <= 0) THEN
    RETURN jsonb_build_object(
      'is_valid', FALSE,
      'reason', '团课课时不足',
      'details', jsonb_build_object(
        'remaining_group_sessions', v_card.remaining_group_sessions
      )
    );
  END IF;
  
  -- 检查私教课时是否足够
  IF v_card.card_type = '私教课' AND
     (v_card.remaining_private_sessions IS NULL OR v_card.remaining_private_sessions <= 0) THEN
    RETURN jsonb_build_object(
      'is_valid', FALSE,
      'reason', '私教课时不足',
      'details', jsonb_build_object(
        'remaining_private_sessions', v_card.remaining_private_sessions
      )
    );
  END IF;
  
  -- 会员卡有效
  RETURN jsonb_build_object(
    'is_valid', TRUE,
    'card_info', jsonb_build_object(
      'card_id', v_card.id,
      'card_type', v_card.card_type,
      'card_category', v_card.card_category,
      'card_subtype', v_card.card_subtype,
      'valid_until', v_card.valid_until,
      'remaining_group_sessions', v_card.remaining_group_sessions,
      'remaining_private_sessions', v_card.remaining_private_sessions
    )
  );
END;
$$;

-- 更新查找有效会员卡的触发器函数
CREATE OR REPLACE FUNCTION find_valid_card_for_checkin()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
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
    v_card_type := '私教课';
  ELSE
    v_card_type := '团课';
  END IF;
  
  -- 查找有效的会员卡
  -- 优先查找课时卡，其次是月卡
  SELECT id INTO v_card_id
  FROM membership_cards
  WHERE member_id = NEW.member_id
    AND (
      -- 对于私教课
      (v_is_private AND card_type = '私教课' AND 
       (remaining_private_sessions IS NULL OR remaining_private_sessions > 0))
      OR
      -- 对于团课
      (NOT v_is_private AND card_type = '团课' AND 
       ((card_category = '课时卡' AND (remaining_group_sessions IS NULL OR remaining_group_sessions > 0))
        OR card_category = '月卡'))
    )
    AND (valid_until IS NULL OR valid_until >= NEW.check_in_date)
  ORDER BY 
    -- 优先使用课时卡
    CASE WHEN card_category = '课时卡' THEN 0 ELSE 1 END,
    -- 优先使用即将过期的卡
    CASE WHEN valid_until IS NOT NULL THEN valid_until ELSE '9999-12-31'::DATE END
  LIMIT 1;
  
  -- 如果找到有效会员卡，则关联到签到记录
  IF v_card_id IS NOT NULL THEN
    NEW.card_id = v_card_id;
    
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
        'member_id', NEW.member_id
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$;

-- 删除现有函数
DROP FUNCTION IF EXISTS check_member_exists(uuid);

-- 重新创建check_member_exists函数
CREATE OR REPLACE FUNCTION check_member_exists(p_member_id uuid)
RETURNS boolean
LANGUAGE plpgsql
AS $function$
DECLARE
  v_member RECORD;
BEGIN
  -- 获取会员信息
  SELECT *
  INTO v_member
  FROM members
  WHERE id = p_member_id;

  -- 记录验证日志
  PERFORM log_debug(
    'check_member_exists',
    CASE WHEN FOUND THEN '会员验证成功' ELSE '会员不存在' END,
    jsonb_build_object(
      'member_id', p_member_id,
      'exists', FOUND,
      'details', CASE 
        WHEN FOUND THEN jsonb_build_object(
          'name', v_member.name,
          'email', v_member.email,
          'is_new_member', v_member.is_new_member,
          'created_at', v_member.created_at
        )
        ELSE NULL
      END
    )
  );

  RETURN FOUND;
END;
$function$;

-- 修改validate_check_in函数
CREATE OR REPLACE FUNCTION validate_check_in()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
  v_member RECORD;
  v_card RECORD;
  v_daily_check_ins integer;
  v_has_same_class_check_in boolean;
  v_is_private boolean;
BEGIN
  -- 检查会员是否存在
  IF NOT check_member_exists(NEW.member_id) THEN
    RAISE EXCEPTION '会员不存在';
  END IF;

  -- 获取会员信息
  SELECT *
  INTO v_member
  FROM members
  WHERE id = NEW.member_id;

  -- 设置是否为私教课
  v_is_private := (NEW.class_type = 'private');

  -- 记录开始验证
  PERFORM log_debug(
    'validate_check_in',
    '开始签到验证',
    jsonb_build_object(
      'member_id', NEW.member_id,
      'class_type', NEW.class_type,
      'check_in_date', NEW.check_in_date,
      'time_slot', NEW.time_slot,
      'is_private', v_is_private
    )
  );

  -- 检查是否重复签到
  IF check_duplicate_check_in(NEW.member_id, NEW.check_in_date, NEW.class_type::TEXT, NEW.time_slot) THEN
    PERFORM log_debug(
      'validate_check_in',
      '重复签到',
      jsonb_build_object(
        'member_id', NEW.member_id,
        'class_type', NEW.class_type,
        'check_in_date', NEW.check_in_date,
        'time_slot', NEW.time_slot
      )
    );
    RAISE EXCEPTION '今天已经在这个时段签到过了';
  END IF;

  -- 验证会员卡
  IF NEW.card_id IS NOT NULL THEN
    -- 获取会员卡信息
    SELECT *
    INTO v_card
    FROM membership_cards
    WHERE id = NEW.card_id;

    -- 检查会员卡是否存在
    IF NOT FOUND THEN
      PERFORM log_debug(
        'validate_check_in',
        '会员卡不存在',
        jsonb_build_object(
          'card_id', NEW.card_id
        )
      );
      RAISE EXCEPTION '会员卡不存在';
    END IF;

    -- 检查会员卡是否属于该会员
    IF v_card.member_id != NEW.member_id THEN
      PERFORM log_debug(
        'validate_check_in',
        '会员卡不属于该会员',
        jsonb_build_object(
          'card_id', NEW.card_id,
          'card_member_id', v_card.member_id,
          'check_in_member_id', NEW.member_id
        )
      );
      RAISE EXCEPTION '会员卡不属于该会员';
    END IF;

    -- 检查会员卡是否过期
    IF v_card.valid_until IS NOT NULL AND v_card.valid_until < NEW.check_in_date THEN
      PERFORM log_debug(
        'validate_check_in',
        '会员卡已过期',
        jsonb_build_object(
          'card_id', NEW.card_id,
          'valid_until', v_card.valid_until,
          'check_in_date', NEW.check_in_date
        )
      );
      NEW.is_extra := true;
    END IF;

    -- 检查卡类型是否匹配课程类型
    IF (v_card.card_type = '团课' AND v_is_private) OR
       (v_card.card_type = '私教课' AND NOT v_is_private) THEN
      PERFORM log_debug(
        'validate_check_in',
        '卡类型与课程类型不匹配',
        jsonb_build_object(
          'card_id', NEW.card_id,
          'card_type', v_card.card_type,
          'class_type', NEW.class_type,
          'is_private', v_is_private
        )
      );
      NEW.is_extra := true;
    END IF;

    -- 检查剩余课时
    IF v_is_private AND v_card.remaining_private_sessions <= 0 THEN
      PERFORM log_debug(
        'validate_check_in',
        '私教课时不足',
        jsonb_build_object(
          'card_id', NEW.card_id,
          'remaining_sessions', v_card.remaining_private_sessions
        )
      );
      NEW.is_extra := true;
    ELSIF NOT v_is_private AND v_card.remaining_group_sessions <= 0 THEN
      PERFORM log_debug(
        'validate_check_in',
        '团课课时不足',
        jsonb_build_object(
          'card_id', NEW.card_id,
          'remaining_sessions', v_card.remaining_group_sessions
        )
      );
      NEW.is_extra := true;
    END IF;
  ELSE
    -- 没有指定会员卡
    PERFORM log_debug(
      'validate_check_in',
      '未指定会员卡',
      jsonb_build_object(
        'member_id', NEW.member_id,
        'class_type', NEW.class_type
      )
    );
    NEW.is_extra := true;
  END IF;

  -- 记录验证结果
  PERFORM log_debug(
    'validate_check_in',
    '签到验证完成',
    jsonb_build_object(
      'member_id', NEW.member_id,
      'card_id', NEW.card_id,
      'class_type', NEW.class_type,
      'is_extra', NEW.is_extra,
      'validation_result', CASE 
        WHEN NEW.is_extra THEN '额外签到'
        ELSE '正常签到'
      END
    )
  );

  RETURN NEW;
END;
$function$;

-- 创建或更新签到验证触发器
DROP TRIGGER IF EXISTS check_in_validation_trigger ON check_ins;
CREATE TRIGGER check_in_validation_trigger
  BEFORE INSERT OR UPDATE ON check_ins
  FOR EACH ROW
  EXECUTE FUNCTION validate_check_in();

-- 修改deduct_membership_sessions函数
CREATE OR REPLACE FUNCTION deduct_membership_sessions(
  p_card_id uuid,
  p_class_type text,
  p_is_private boolean
)
RETURNS void
LANGUAGE plpgsql
AS $function$
DECLARE
  v_card RECORD;
  v_class_type class_type;
BEGIN
  -- 记录开始扣除课时
  PERFORM log_debug(
    'deduct_membership_sessions',
    '开始扣除课时',
    jsonb_build_object(
      'card_id', p_card_id,
      'class_type', p_class_type,
      'is_private', p_is_private
    )
  );

  -- 获取会员卡信息
  SELECT *
  INTO v_card
  FROM membership_cards
  WHERE id = p_card_id
  FOR UPDATE;

  -- 检查会员卡是否存在
  IF NOT FOUND THEN
    PERFORM log_debug(
      'deduct_membership_sessions',
      '会员卡不存在',
      jsonb_build_object(
        'card_id', p_card_id
      )
    );
    RAISE EXCEPTION '会员卡不存在';
  END IF;

  -- 转换课程类型
  BEGIN
    v_class_type := p_class_type::class_type;
  EXCEPTION WHEN OTHERS THEN
    PERFORM log_debug(
      'deduct_membership_sessions',
      '无效的课程类型',
      jsonb_build_object(
        'class_type', p_class_type,
        'error', SQLERRM
      )
    );
    RAISE EXCEPTION '无效的课程类型: %', p_class_type;
  END;

  -- 检查卡类型与课程类型是否匹配
  IF (v_card.card_type = '团课' AND p_is_private) OR
     (v_card.card_type = '私教课' AND NOT p_is_private) THEN
    PERFORM log_debug(
      'deduct_membership_sessions',
      '卡类型与课程类型不匹配',
      jsonb_build_object(
        'card_id', p_card_id,
        'card_type', v_card.card_type,
        'class_type', v_class_type,
        'is_private', p_is_private
      )
    );
    RAISE EXCEPTION '卡类型与课程类型不匹配';
  END IF;

  -- 检查剩余课时
  IF p_is_private THEN
    IF v_card.remaining_private_sessions <= 0 THEN
      PERFORM log_debug(
        'deduct_membership_sessions',
        '私教课时不足',
        jsonb_build_object(
          'card_id', p_card_id,
          'remaining_sessions', v_card.remaining_private_sessions
        )
      );
      RAISE EXCEPTION '私教课时不足';
    END IF;

    -- 扣除私教课时
    UPDATE membership_cards
    SET remaining_private_sessions = remaining_private_sessions - 1
    WHERE id = p_card_id;

    PERFORM log_debug(
      'deduct_membership_sessions',
      '扣除私教课时成功',
      jsonb_build_object(
        'card_id', p_card_id,
        'remaining_sessions', v_card.remaining_private_sessions - 1
      )
    );
  ELSE
    IF v_card.remaining_group_sessions <= 0 THEN
      PERFORM log_debug(
        'deduct_membership_sessions',
        '团课课时不足',
        jsonb_build_object(
          'card_id', p_card_id,
          'remaining_sessions', v_card.remaining_group_sessions
        )
      );
      RAISE EXCEPTION '团课课时不足';
    END IF;

    -- 扣除团课课时
    UPDATE membership_cards
    SET remaining_group_sessions = remaining_group_sessions - 1
    WHERE id = p_card_id;

    PERFORM log_debug(
      'deduct_membership_sessions',
      '扣除团课课时成功',
      jsonb_build_object(
        'card_id', p_card_id,
        'remaining_sessions', v_card.remaining_group_sessions - 1
      )
    );
  END IF;

  -- 记录扣除课时完成
  PERFORM log_debug(
    'deduct_membership_sessions',
    '扣除课时完成',
    jsonb_build_object(
      'card_id', p_card_id,
      'card_type', v_card.card_type,
      'class_type', v_class_type,
      'is_private', p_is_private,
      'remaining_group_sessions', CASE 
        WHEN NOT p_is_private THEN v_card.remaining_group_sessions - 1
        ELSE v_card.remaining_group_sessions
      END,
      'remaining_private_sessions', CASE
        WHEN p_is_private THEN v_card.remaining_private_sessions - 1
        ELSE v_card.remaining_private_sessions
      END
    )
  );
END;
$function$;

-- 修改handle_check_in函数
CREATE OR REPLACE FUNCTION handle_check_in(
  p_member_id uuid,
  p_name text,
  p_email text,
  p_class_type text,
  p_check_in_date date,
  p_card_id uuid DEFAULT NULL,
  p_trainer_id uuid DEFAULT NULL,
  p_is_1v2 boolean DEFAULT false,
  p_time_slot text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
AS $function$
DECLARE
  v_result jsonb;
  v_is_extra boolean;
  v_check_in_id uuid;
  v_class_type class_type;
  v_card_validity jsonb;
  v_is_new_member boolean := false;
  v_is_private boolean;
BEGIN
  -- 记录开始处理
  PERFORM log_debug(
    'handle_check_in',
    '开始处理签到',
    jsonb_build_object(
      'member_id', p_member_id,
      'name', p_name,
      'email', p_email,
      'class_type', p_class_type,
      'check_in_date', p_check_in_date,
      'card_id', p_card_id,
      'trainer_id', p_trainer_id,
      'is_1v2', p_is_1v2,
      'time_slot', p_time_slot
    )
  );

  -- 转换课程类型
  BEGIN
    v_class_type := p_class_type::class_type;
    v_is_private := (v_class_type = 'private');
  EXCEPTION WHEN OTHERS THEN
    PERFORM log_debug(
      'handle_check_in',
      '无效的课程类型',
      jsonb_build_object(
        'class_type', p_class_type,
        'error', SQLERRM
      )
    );
    RETURN jsonb_build_object(
      'success', false,
      'message', '无效的课程类型: ' || p_class_type,
      'error', SQLERRM
    );
  END;

  -- 验证时间段
  IF p_time_slot IS NULL THEN
    PERFORM log_debug(
      'handle_check_in',
      '缺少时间段',
      jsonb_build_object(
        'member_id', p_member_id,
        'class_type', p_class_type
      )
    );
    RETURN jsonb_build_object(
      'success', false,
      'message', '请选择有效的时间段',
      'error', 'time_slot_required'
    );
  END IF;

  -- 开始事务
  BEGIN
    -- 检查会员是否存在
    IF NOT check_member_exists(p_member_id) THEN
      -- 创建新会员
      INSERT INTO members(id, name, email, is_new_member)
      VALUES (p_member_id, p_name, p_email, true);
      
      v_is_extra := true;
      v_is_new_member := true;
      
      PERFORM log_debug(
        'handle_check_in',
        '创建新会员',
        jsonb_build_object(
          'member_id', p_member_id,
          'name', p_name,
          'email', p_email
        )
      );
    END IF;

    -- 检查是否重复签到
    v_result := check_duplicate_check_in(p_member_id, p_check_in_date, p_class_type, p_time_slot);
    IF (v_result->>'has_duplicate')::boolean THEN
      PERFORM log_debug(
        'handle_check_in',
        '重复签到',
        jsonb_build_object(
          'member_id', p_member_id,
          'details', v_result->'details'
        )
      );
      RETURN jsonb_build_object(
        'success', false,
        'message', v_result->>'message',
        'isDuplicate', true
      );
    END IF;

    -- 验证会员卡
    IF p_card_id IS NOT NULL THEN
      v_card_validity := check_card_validity(p_card_id, p_member_id, p_class_type, p_check_in_date, p_trainer_id);
      
      IF (v_card_validity->>'is_valid')::boolean THEN
        v_is_extra := false;
      ELSE
        v_is_extra := true;
        
        PERFORM log_debug(
          'handle_check_in',
          '会员卡验证失败',
          jsonb_build_object(
            'reason', v_card_validity->>'reason',
            'details', v_card_validity->'details'
          )
        );
      END IF;
    ELSE
      v_is_extra := true;
      
      PERFORM log_debug(
        'handle_check_in',
        '未指定会员卡',
        jsonb_build_object(
          'member_id', p_member_id,
          'class_type', p_class_type
        )
      );
    END IF;

    -- 插入签到记录
    INSERT INTO check_ins(
      member_id,
      card_id,
      class_type,
      check_in_date,
      trainer_id,
      is_1v2,
      is_extra,
      time_slot,
      is_private
    )
    VALUES (
      p_member_id,
      p_card_id,
      v_class_type,
      p_check_in_date,
      CASE WHEN v_is_private THEN p_trainer_id ELSE NULL END,
      CASE WHEN v_is_private THEN p_is_1v2 ELSE false END,
      v_is_extra,
      p_time_slot,
      v_is_private
    )
    RETURNING id INTO v_check_in_id;

    -- 更新会员信息
    UPDATE members
    SET
      extra_check_ins = CASE WHEN v_is_extra THEN extra_check_ins + 1 ELSE extra_check_ins END,
      last_check_in_date = p_check_in_date
    WHERE id = p_member_id;

    -- 如果是正常签到,扣除课时
    IF NOT v_is_extra AND p_card_id IS NOT NULL THEN
      PERFORM deduct_membership_sessions(p_card_id, p_class_type, v_is_private);
    END IF;

    -- 记录签到完成
    PERFORM log_debug(
      'handle_check_in',
      '签到完成',
      jsonb_build_object(
        'check_in_id', v_check_in_id,
        'member_id', p_member_id,
        'card_id', p_card_id,
        'class_type', v_class_type,
        'is_extra', v_is_extra,
        'is_new_member', v_is_new_member
      )
    );

    -- 返回成功结果
    RETURN jsonb_build_object(
      'success', true,
      'check_in_id', v_check_in_id,
      'is_extra', v_is_extra,
      'is_new_member', v_is_new_member
    );

  EXCEPTION WHEN OTHERS THEN
    -- 记录错误
    PERFORM log_debug(
      'handle_check_in',
      '签到失败',
      jsonb_build_object(
        'member_id', p_member_id,
        'error', SQLERRM,
        'details', jsonb_build_object(
          'class_type', p_class_type,
          'check_in_date', p_check_in_date,
          'card_id', p_card_id
        )
      )
    );

    -- 返回错误结果
    RETURN jsonb_build_object(
      'success', false,
      'message', SQLERRM,
      'error', SQLERRM
    );
  END;
END;
$function$;

-- 修改check_duplicate_check_in函数
CREATE OR REPLACE FUNCTION check_duplicate_check_in(
  p_member_id uuid,
  p_date date,
  p_class_type text,
  p_time_slot text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
AS $function$
DECLARE
  v_class_type class_type;
  v_is_private boolean;
  v_duplicate_check_in RECORD;
BEGIN
  -- 记录开始检查
  PERFORM log_debug(
    'check_duplicate_check_in',
    '开始检查重复签到',
    jsonb_build_object(
      'member_id', p_member_id,
      'date', p_date,
      'class_type', p_class_type,
      'time_slot', p_time_slot
    )
  );

  -- 转换课程类型
  BEGIN
    v_class_type := p_class_type::class_type;
    v_is_private := (v_class_type = 'private');
  EXCEPTION WHEN OTHERS THEN
    PERFORM log_debug(
      'check_duplicate_check_in',
      '无效的课程类型',
      jsonb_build_object(
        'class_type', p_class_type,
        'error', SQLERRM
      )
    );
    RETURN jsonb_build_object(
      'has_duplicate', false,
      'message', '无效的课程类型: ' || p_class_type,
      'details', jsonb_build_object(
        'error', SQLERRM
      )
    );
  END;

  -- 检查重复签到
  SELECT *
  INTO v_duplicate_check_in
  FROM check_ins
  WHERE member_id = p_member_id
    AND check_in_date = p_date
    AND class_type = v_class_type
    AND (p_time_slot IS NULL OR time_slot = p_time_slot);

  -- 记录检查结果
  IF FOUND THEN
    PERFORM log_debug(
      'check_duplicate_check_in',
      '发现重复签到',
      jsonb_build_object(
        'member_id', p_member_id,
        'date', p_date,
        'class_type', v_class_type,
        'time_slot', COALESCE(p_time_slot, v_duplicate_check_in.time_slot),
        'duplicate_check_in', jsonb_build_object(
          'id', v_duplicate_check_in.id,
          'check_in_date', v_duplicate_check_in.check_in_date,
          'time_slot', v_duplicate_check_in.time_slot,
          'is_extra', v_duplicate_check_in.is_extra
        )
      )
    );

    RETURN jsonb_build_object(
      'has_duplicate', true,
      'message', CASE
        WHEN v_is_private THEN '今天已经签到过私教课'
        ELSE '今天已经签到过团课'
      END,
      'details', jsonb_build_object(
        'duplicate_check_in_id', v_duplicate_check_in.id,
        'check_in_date', v_duplicate_check_in.check_in_date,
        'time_slot', v_duplicate_check_in.time_slot,
        'is_extra', v_duplicate_check_in.is_extra
      )
    );
  END IF;

  -- 记录无重复签到
  PERFORM log_debug(
    'check_duplicate_check_in',
    '未发现重复签到',
    jsonb_build_object(
      'member_id', p_member_id,
      'date', p_date,
      'class_type', v_class_type,
      'time_slot', p_time_slot
    )
  );

  RETURN jsonb_build_object(
    'has_duplicate', false,
    'message', '未发现重复签到'
  );
END;
$function$;

-- 记录迁移完成
INSERT INTO migration_logs (migration_name, description)
VALUES ('20250401000003_update_card_validation_functions', '更新会员卡验证函数完成'); 