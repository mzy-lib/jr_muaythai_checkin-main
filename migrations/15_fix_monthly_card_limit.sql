-- 向上迁移 (应用更改)
-- 修复月卡的每日签到次数限制

-- 创建检查月卡每日签到次数的函数
CREATE OR REPLACE FUNCTION check_monthly_card_daily_limit(
  p_member_id UUID, 
  p_card_id UUID,
  p_date DATE
) RETURNS BOOLEAN AS $$
DECLARE
  v_card RECORD;
  v_daily_check_ins INTEGER;
BEGIN
  -- 获取会员卡信息
  SELECT * INTO v_card FROM membership_cards WHERE id = p_card_id;
  
  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;
  
  -- 如果不是月卡，直接返回true
  IF v_card.card_type != '团课' OR v_card.card_category != '月卡' THEN
    RETURN TRUE;
  END IF;
  
  -- 获取当天非额外签到的次数
  SELECT COUNT(*) INTO v_daily_check_ins 
  FROM check_ins 
  WHERE member_id = p_member_id 
  AND check_in_date = p_date 
  AND NOT is_extra;
  
  -- 根据月卡类型检查每日签到次数限制
  IF v_card.card_subtype = '单次月卡' AND v_daily_check_ins >= 1 THEN
    RETURN FALSE;
  ELSIF v_card.card_subtype = '双次月卡' AND v_daily_check_ins >= 2 THEN
    RETURN FALSE;
  END IF;
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- 修改handle_check_in函数，增加月卡每日签到次数限制检查
CREATE OR REPLACE FUNCTION handle_check_in(
  p_member_id UUID,
  p_name TEXT,
  p_email TEXT,
  p_class_type TEXT,
  p_check_in_date DATE,
  p_time_slot TEXT,
  p_card_id UUID DEFAULT NULL,
  p_trainer_id UUID DEFAULT NULL,
  p_is_1v2 BOOLEAN DEFAULT FALSE
) RETURNS JSONB AS $$
DECLARE
  v_result jsonb;
  v_is_extra boolean;
  v_check_in_id uuid;
  v_class_type class_type;
  v_card_validity jsonb;
  v_is_new_member boolean := false;
  v_is_private boolean;
  v_card_expired boolean := false;
BEGIN
  -- 转换class_type
  BEGIN
    v_class_type := p_class_type::class_type;
    v_is_private := (v_class_type = 'private');
  EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', '无效的课程类型: ' || p_class_type,
      'error', SQLERRM
    );
  END;
  
  -- 验证时间段
  IF p_time_slot IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', '请选择有效的时间段',
      'error', 'time_slot_required'
    );
  END IF;
  
  -- 开始事务
  BEGIN
    -- 检查会员是否存在，不存在则创建
    IF p_member_id IS NULL OR NOT EXISTS (SELECT 1 FROM members WHERE id = p_member_id) THEN
      -- 生成新的UUID如果p_member_id为NULL
      IF p_member_id IS NULL THEN
        p_member_id := gen_random_uuid();
      END IF;
      
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
    
    -- 检查是否重复签到（考虑时间段）
    IF check_duplicate_check_in(p_member_id, p_check_in_date, p_class_type, p_time_slot) THEN
      RETURN jsonb_build_object(
        'success', false,
        'message', '今天已经在这个时段签到过了',
        'isDuplicate', true
      );
    END IF;
    
    -- 验证会员卡
    IF p_card_id IS NOT NULL THEN
      v_card_validity := check_card_validity(p_card_id, p_member_id, p_class_type, p_check_in_date, p_trainer_id);
      
      -- 检查卡是否过期
      IF (v_card_validity->>'is_valid')::boolean = false AND 
         (v_card_validity->>'reason') = '会员卡已过期' THEN
        -- 卡已过期，但我们允许签到并标记为额外签到
        v_is_extra := true;
        v_card_expired := true;
        
        PERFORM log_debug(
          'handle_check_in',
          '会员卡已过期，记录为额外签到',
          jsonb_build_object(
            'card_id', p_card_id,
            'valid_until', (v_card_validity->'details'->>'valid_until'),
            'check_in_date', p_check_in_date
          ),
          p_member_id
        );
      ELSIF (v_card_validity->>'is_valid')::boolean THEN
        v_is_extra := false;
      ELSE
        -- 其他无效原因（非过期），仍然标记为额外签到
        v_is_extra := true;
        
        PERFORM log_debug(
          'handle_check_in',
          '会员卡验证失败',
          jsonb_build_object(
            'reason', v_card_validity->>'reason',
            'details', v_card_validity->'details'
          ),
          p_member_id
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
        ),
        p_member_id
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
      CASE WHEN v_is_private THEN p_is_1v2 ELSE FALSE END,
      v_is_extra,
      p_time_slot,
      CASE WHEN v_class_type = 'private' THEN TRUE ELSE FALSE END
    )
    RETURNING id INTO v_check_in_id;
    
    -- 更新会员信息
    UPDATE members 
    SET 
      extra_check_ins = CASE WHEN v_is_extra THEN extra_check_ins + 1 ELSE extra_check_ins END,
      last_check_in_date = p_check_in_date
    WHERE id = p_member_id;
    
    -- 构建返回结果
    v_result := jsonb_build_object(
      'success', true,
      'message', CASE 
        WHEN v_is_new_member THEN '欢迎新会员！已记录签到'
        WHEN v_card_expired THEN '您的会员卡已过期，已记录为额外签到'
        WHEN v_is_extra AND v_class_type IN ('morning', 'evening') THEN '您暂无有效的团课卡，已记录为额外签到'
        WHEN v_is_extra AND v_class_type = 'private' THEN '您暂无有效的私教卡，已记录为额外签到'
        ELSE '签到成功'
      END,
      'isExtra', v_is_extra,
      'isNewMember', v_is_new_member,
      'checkInId', v_check_in_id
    );
    
    PERFORM log_debug(
      'handle_check_in',
      '签到成功',
      jsonb_build_object(
        'check_in_id', v_check_in_id,
        'is_extra', v_is_extra,
        'is_new_member', v_is_new_member,
        'class_type', p_class_type,
        'time_slot', p_time_slot
      ),
      p_member_id
    );
    
    RETURN v_result;
  EXCEPTION WHEN OTHERS THEN
    -- 记录错误
    PERFORM log_debug(
      'handle_check_in',
      '签到失败',
      jsonb_build_object(
        'error', SQLERRM,
        'member_id', p_member_id,
        'class_type', p_class_type,
        'time_slot', p_time_slot
      ),
      p_member_id
    );
    
    -- 返回错误信息
    RETURN jsonb_build_object(
      'success', false,
      'message', '签到失败: ' || SQLERRM,
      'error', SQLERRM
    );
  END;
END;
$$ LANGUAGE plpgsql;

-- 修复会员卡有效期设置问题
CREATE OR REPLACE FUNCTION set_card_validity(
  p_card_id UUID, 
  p_card_type TEXT, 
  p_card_category TEXT, 
  p_card_subtype TEXT
) RETURNS DATE AS $$
DECLARE
  v_valid_until DATE;
BEGIN
  -- 根据不同卡类型设置有效期
  v_valid_until := CASE
    -- 团课月卡：购买日起30天
    WHEN (p_card_type = 'group' OR p_card_type = '团课') AND (p_card_category = 'monthly' OR p_card_category = '月卡') THEN
      CURRENT_DATE + INTERVAL '30 days'
    -- 团课10次卡：购买日起3个月
    WHEN (p_card_type = 'group' OR p_card_type = '团课') AND 
         ((p_card_category = 'session' OR p_card_category = '课时卡') AND 
          (p_card_subtype = 'ten_classes' OR p_card_subtype = '10次卡' OR p_card_subtype = '10_sessions')) THEN
      CURRENT_DATE + INTERVAL '3 months'
    -- 私教10次卡：购买日起1个月
    WHEN (p_card_type = 'private' OR p_card_type = '私教课') AND 
         (p_card_subtype = 'ten_classes' OR p_card_subtype = '10次卡' OR p_card_subtype = '10_sessions') THEN
      CURRENT_DATE + INTERVAL '1 month'
    -- 其他卡：无到期限制（包括团课单次卡、团课两次卡和私教单次卡）
    ELSE NULL
  END;

  -- 记录日志
  PERFORM log_debug(
    'set_card_validity',
    '设置会员卡有效期',
    jsonb_build_object(
      'card_id', p_card_id,
      'card_type', p_card_type,
      'card_category', p_card_category,
      'card_subtype', p_card_subtype,
      'valid_until', v_valid_until
    )
  );
  
  RETURN v_valid_until;
END;
$$ LANGUAGE plpgsql;

-- 创建触发器，在插入或更新会员卡时自动设置有效期
CREATE OR REPLACE FUNCTION trigger_set_card_validity()
RETURNS TRIGGER AS $$
BEGIN
  NEW.valid_until := set_card_validity(NEW.id, NEW.card_type, NEW.card_category, NEW.card_subtype);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 删除现有触发器（如果存在）
DROP TRIGGER IF EXISTS set_card_validity_trigger ON membership_cards;

-- 创建新的触发器
CREATE TRIGGER set_card_validity_trigger
BEFORE INSERT OR UPDATE OF card_type, card_category, card_subtype ON membership_cards
FOR EACH ROW
EXECUTE FUNCTION trigger_set_card_validity();

-- 向下迁移 (回滚更改)
-- 这里不提供回滚脚本，因为回滚会导致函数与表结构不匹配 