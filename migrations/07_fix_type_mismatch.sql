-- 向上迁移 (应用更改)
-- 修复函数中的类型不匹配问题

-- 修复 check_duplicate_check_in 函数
CREATE OR REPLACE FUNCTION check_duplicate_check_in(p_member_id UUID, p_date DATE, p_class_type TEXT) 
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM check_ins 
    WHERE member_id = p_member_id 
    AND check_in_date = p_date 
    AND class_type::TEXT = p_class_type
  );
END;
$$ LANGUAGE plpgsql;

-- 修复 check_card_validity 函数
CREATE OR REPLACE FUNCTION check_card_validity(p_card_id UUID, p_member_id UUID, p_class_type TEXT, p_check_in_date DATE) 
RETURNS BOOLEAN AS $$
DECLARE
  v_card RECORD;
BEGIN
  SELECT * INTO v_card FROM membership_cards WHERE id = p_card_id;
  
  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;
  
  IF v_card.member_id != p_member_id THEN
    RETURN FALSE;
  END IF;
  
  -- 根据实际情况调整类型比较
  IF (v_card.card_type = 'group' AND p_class_type = 'private') OR 
     (v_card.card_type = 'private' AND p_class_type != 'private') THEN
    RETURN FALSE;
  END IF;
  
  IF v_card.valid_until IS NOT NULL AND v_card.valid_until < p_check_in_date THEN
    RETURN FALSE;
  END IF;
  
  IF v_card.card_type = 'group' AND v_card.card_category = 'session' AND 
     (v_card.remaining_group_sessions IS NULL OR v_card.remaining_group_sessions <= 0) THEN
    RETURN FALSE;
  END IF;
  
  IF v_card.card_type = 'private' AND 
     (v_card.remaining_private_sessions IS NULL OR v_card.remaining_private_sessions <= 0) THEN
    RETURN FALSE;
  END IF;
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- 修复 deduct_membership_sessions 函数
CREATE OR REPLACE FUNCTION deduct_membership_sessions(p_card_id UUID, p_class_type TEXT) 
RETURNS VOID AS $$
DECLARE
  v_card RECORD;
BEGIN
  -- 锁定会员卡记录
  SELECT * INTO v_card 
  FROM membership_cards 
  WHERE id = p_card_id 
  FOR UPDATE;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION '会员卡不存在';
  END IF;
  
  -- 根据课程类型扣除课时
  IF v_card.card_type = 'group' AND v_card.card_category = 'session' THEN
    UPDATE membership_cards 
    SET remaining_group_sessions = remaining_group_sessions - 1 
    WHERE id = p_card_id;
  ELSIF v_card.card_type = 'private' THEN
    UPDATE membership_cards 
    SET remaining_private_sessions = remaining_private_sessions - 1 
    WHERE id = p_card_id;
  END IF;
  
  -- 记录日志
  IF current_setting('app.environment', true) = 'development' THEN
    INSERT INTO debug_logs (function_name, message, details)
    VALUES ('deduct_membership_sessions', '扣除课时', 
      jsonb_build_object(
        'card_id', p_card_id,
        'class_type', p_class_type,
        'card_type', v_card.card_type,
        'card_category', v_card.card_category
      )
    );
  END IF;
END;
$$ LANGUAGE plpgsql;

-- 修复 handle_check_in 函数
CREATE OR REPLACE FUNCTION handle_check_in(
  p_member_id UUID,
  p_name TEXT,
  p_email TEXT,
  p_card_id UUID,
  p_class_type TEXT,
  p_check_in_date DATE,
  p_trainer_id UUID DEFAULT NULL,
  p_is_1v2 BOOLEAN DEFAULT FALSE
) RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
  v_is_extra BOOLEAN;
  v_check_in_id UUID;
BEGIN
  -- 开始事务
  BEGIN
    -- 检查会员是否存在，不存在则创建
    IF NOT check_member_exists(p_member_id) THEN
      INSERT INTO members(id, name, email, is_new_member)
      VALUES (p_member_id, p_name, p_email, true);
      
      v_is_extra := true;
    END IF;
    
    -- 检查是否重复签到
    IF check_duplicate_check_in(p_member_id, p_check_in_date, p_class_type) THEN
      RETURN jsonb_build_object(
        'success', false,
        'message', '今天已经在这个时段签到过了',
        'isDuplicate', true
      );
    END IF;
    
    -- 验证会员卡
    IF p_card_id IS NOT NULL THEN
      IF NOT check_card_validity(p_card_id, p_member_id, p_class_type, p_check_in_date) THEN
        v_is_extra := true;
      ELSE
        v_is_extra := false;
      END IF;
    ELSE
      v_is_extra := true;
    END IF;
    
    -- 插入签到记录
    INSERT INTO check_ins(
      member_id, 
      card_id, 
      class_type, 
      check_in_date,
      trainer_id,
      is_1v2,
      is_extra
    )
    VALUES (
      p_member_id,
      p_card_id,
      p_class_type::class_type,  -- 显式类型转换
      p_check_in_date,
      CASE WHEN p_class_type = 'private' THEN p_trainer_id ELSE NULL END,
      CASE WHEN p_class_type = 'private' THEN p_is_1v2 ELSE FALSE END,
      v_is_extra
    )
    RETURNING id INTO v_check_in_id;
    
    -- 扣除课时
    IF p_card_id IS NOT NULL AND NOT v_is_extra THEN
      PERFORM deduct_membership_sessions(p_card_id, p_class_type);
    END IF;
    
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
        WHEN v_is_extra AND p_class_type = 'group' THEN '您暂无有效的团课卡，已记录为额外签到'
        WHEN v_is_extra AND p_class_type = 'private' THEN '您暂无有效的私教卡，已记录为额外签到'
        ELSE '签到成功'
      END,
      'isExtra', v_is_extra,
      'checkInId', v_check_in_id
    );
    
    RETURN v_result;
  EXCEPTION WHEN OTHERS THEN
    -- 记录错误
    IF current_setting('app.environment', true) = 'development' THEN
      INSERT INTO debug_logs (function_name, message, details)
      VALUES ('handle_check_in', '签到失败', 
        jsonb_build_object(
          'error', SQLERRM,
          'member_id', p_member_id,
          'class_type', p_class_type
        )
      );
    END IF;
    
    -- 返回错误信息
    RETURN jsonb_build_object(
      'success', false,
      'message', SQLERRM
    );
  END;
END;
$$ LANGUAGE plpgsql;

-- 向下迁移 (回滚更改)
-- 这里不提供回滚脚本，因为回滚会导致函数与表结构不匹配 