-- 创建用于测试的添加会员卡函数
CREATE OR REPLACE FUNCTION add_membership_card(
  p_member_id UUID,
  p_card_type TEXT,  -- 'group' 或 'private'
  p_card_category TEXT DEFAULT NULL,  -- 'session' 或 'monthly'（对团课）
  p_card_subtype TEXT DEFAULT NULL,   -- 具体卡类型
  p_remaining_group_sessions INT DEFAULT NULL,
  p_remaining_private_sessions INT DEFAULT NULL,
  p_valid_until DATE DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_card_id UUID;
  v_valid_until DATE;
BEGIN
  -- 验证必要字段
  IF p_member_id IS NULL THEN
    RAISE EXCEPTION '会员ID不能为空';
  END IF;
  
  IF p_card_type IS NULL THEN
    RAISE EXCEPTION '会员卡类型不能为空';
  END IF;
  
  -- 设置默认有效期（30天后）
  IF p_valid_until IS NULL THEN
    v_valid_until := CURRENT_DATE + INTERVAL '30 days';
  ELSE
    v_valid_until := p_valid_until;
  END IF;
  
  -- 创建会员卡
  INSERT INTO membership_cards (
    member_id,
    card_type,
    card_category,
    card_subtype,
    remaining_group_sessions,
    remaining_private_sessions,
    valid_until,
    created_at
  ) VALUES (
    p_member_id,
    p_card_type,
    p_card_category,
    p_card_subtype,
    p_remaining_group_sessions,
    p_remaining_private_sessions,
    v_valid_until,
    NOW()
  ) RETURNING id INTO v_card_id;
  
  -- 返回结果
  RETURN json_build_object(
    'success', TRUE,
    'card_id', v_card_id
  );
END;
$$;

-- 设置函数权限
GRANT EXECUTE ON FUNCTION add_membership_card(UUID, TEXT, TEXT, TEXT, INT, INT, DATE) TO postgres, anon, authenticated, service_role; 