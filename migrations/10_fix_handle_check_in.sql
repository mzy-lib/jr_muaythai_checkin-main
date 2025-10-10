-- 向上迁移 (应用更改)
-- 修复handle_check_in函数的参数类型问题

-- 修复handle_check_in函数
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
  v_class_type class_type;
BEGIN
  -- 转换class_type
  BEGIN
    v_class_type := p_class_type::class_type;
  EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', '无效的课程类型: ' || p_class_type,
      'error', SQLERRM
    );
  END;

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
      is_extra,
      time_slot,
      is_private
    )
    VALUES (
      p_member_id,
      p_card_id,
      v_class_type,
      p_check_in_date,
      CASE WHEN v_class_type = 'private' THEN p_trainer_id ELSE NULL END,
      CASE WHEN v_class_type = 'private' THEN p_is_1v2 ELSE FALSE END,
      v_is_extra,
      CASE 
        WHEN v_class_type = 'morning' THEN '09:00-10:30'
        WHEN v_class_type = 'evening' THEN '17:00-18:30'
        WHEN v_class_type = 'private' THEN '10:30-11:30'
        ELSE '09:00-10:30'
      END,
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
        WHEN v_is_extra AND v_class_type IN ('morning', 'evening') THEN '您暂无有效的团课卡，已记录为额外签到'
        WHEN v_is_extra AND v_class_type = 'private' THEN '您暂无有效的私教卡，已记录为额外签到'
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