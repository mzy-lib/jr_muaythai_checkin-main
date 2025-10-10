-- 向上迁移 (应用更改)
-- 修复额外签到的逻辑

-- 修改check_card_validity函数，添加课时检查
CREATE OR REPLACE FUNCTION check_card_validity(
  p_card_id UUID,
  p_class_type TEXT,
  p_is_private BOOLEAN DEFAULT FALSE,
  p_is_1v2 BOOLEAN DEFAULT FALSE
)
RETURNS BOOLEAN AS $$
DECLARE
  v_card RECORD;
  v_required_sessions INTEGER;
BEGIN
  -- 获取会员卡信息
  SELECT * INTO v_card 
  FROM membership_cards 
  WHERE id = p_card_id;
  
  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;

  -- 检查会员卡是否过期
  IF v_card.valid_until < CURRENT_DATE THEN
    RETURN FALSE;
  END IF;

  -- 检查课时是否足够
  IF NOT p_is_private AND p_class_type IN ('morning', 'evening') AND v_card.card_type = '团课' AND v_card.card_category = '课时卡' THEN
    -- 团课需要1次课时
    v_required_sessions := 1;
    RETURN v_card.remaining_group_sessions >= v_required_sessions;
    
  ELSIF p_is_private AND v_card.card_type = '私教课' THEN
    -- 私教课根据1对1或1对2需要不同课时
    v_required_sessions := CASE WHEN p_is_1v2 THEN 2 ELSE 1 END;
    RETURN v_card.remaining_private_sessions >= v_required_sessions;
  END IF;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- 删除旧的handle_check_in函数
DROP FUNCTION IF EXISTS handle_check_in(UUID, TEXT, TEXT, TEXT, DATE, TEXT, UUID, UUID, BOOLEAN);

-- 修改handle_check_in函数，根据课时是否足够来设置is_extra
CREATE OR REPLACE FUNCTION handle_check_in(
  p_member_id UUID,
  p_member_name TEXT,
  p_member_email TEXT,
  p_class_type TEXT,
  p_check_in_date DATE,
  p_time_slot TEXT,
  p_card_id UUID,
  p_trainer_id UUID,
  p_is_1v2 BOOLEAN DEFAULT FALSE
)
RETURNS JSONB AS $$
DECLARE
  v_check_in_id UUID;
  v_is_private BOOLEAN;
  v_is_extra BOOLEAN;
  v_card RECORD;
  v_trainer RECORD;
  v_result JSONB;
  v_is_new_member BOOLEAN;
BEGIN
  -- 获取会员卡信息
  SELECT * INTO v_card 
  FROM membership_cards 
  WHERE id = p_card_id;

  -- 获取教练信息
  SELECT * INTO v_trainer 
  FROM trainers 
  WHERE id = p_trainer_id;

  -- 判断是否为私教课
  v_is_private := v_card.card_type = '私教课';

  -- 检查是否为新会员
  v_is_new_member := EXISTS (
    SELECT 1 
    FROM members 
    WHERE id = p_member_id 
    AND created_at >= CURRENT_DATE - INTERVAL '7 days'
  );

  -- 检查课时是否足够，不足则标记为额外签到
  v_is_extra := NOT check_card_validity(p_card_id, p_class_type, v_is_private, p_is_1v2);

  -- 检查教练等级是否匹配
  IF v_is_private AND NOT v_is_extra AND NOT check_trainer_level_match(v_card.trainer_type, v_trainer.type) THEN
    v_is_extra := TRUE;
  END IF;

  -- 创建签到记录
  INSERT INTO check_ins (
    member_id,
    class_type,
    check_in_date,
    time_slot,
    card_id,
    trainer_id,
    is_private,
    is_1v2,
    is_extra
  )
  VALUES (
    p_member_id,
    p_class_type::class_type,
    p_check_in_date,
    p_time_slot,
    p_card_id,
    p_trainer_id,
    v_is_private,
    p_is_1v2,
    v_is_extra
  )
  RETURNING id INTO v_check_in_id;

  -- 构建返回结果
  v_result := jsonb_build_object(
    'success', TRUE,
    'message', '签到成功',
    'checkInId', v_check_in_id,
    'isExtra', v_is_extra,
    'isNewMember', v_is_new_member
  );

  RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- 修改trigger_deduct_sessions函数，只在非额外签到时扣除课时
CREATE OR REPLACE FUNCTION trigger_deduct_sessions() 
RETURNS TRIGGER AS $$
BEGIN
  -- 只有非额外签到才扣除课时
  IF NOT NEW.is_extra AND NEW.card_id IS NOT NULL THEN
    PERFORM deduct_membership_sessions(NEW.card_id, NEW.class_type::TEXT, NEW.is_private, NEW.is_1v2);
  END IF;
  
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 向下迁移 (回滚更改)
-- 这里不提供回滚脚本，因为这是bug修复 