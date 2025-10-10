-- 向上迁移 (应用更改)
-- 修复会员同时拥有多张有效团课卡的问题

-- 创建检查有效卡的函数
CREATE OR REPLACE FUNCTION check_valid_cards(
  p_member_id UUID,
  p_card_type TEXT,
  p_current_card_id UUID DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
  v_existing_card_id UUID;
BEGIN
  -- 查找除了当前卡之外的其他有效卡
  SELECT id INTO v_existing_card_id
  FROM membership_cards
  WHERE member_id = p_member_id
    AND card_type = p_card_type
    AND id != COALESCE(p_current_card_id, '00000000-0000-0000-0000-000000000000'::UUID)
    AND (valid_until IS NULL OR valid_until >= CURRENT_DATE)
    AND (
      (card_type = '团课' AND (
        (card_category = '课时卡' AND remaining_group_sessions > 0) OR
        card_category = '月卡'
      )) OR
      (card_type = '私教课' AND remaining_private_sessions > 0)
    );

  -- 记录检查结果
  PERFORM log_debug(
    'check_valid_cards',
    '检查有效卡',
    jsonb_build_object(
      'member_id', p_member_id,
      'card_type', p_card_type,
      'current_card_id', p_current_card_id,
      'existing_card_id', v_existing_card_id,
      'has_valid_card', v_existing_card_id IS NOT NULL
    )
  );

  RETURN v_existing_card_id IS NULL;
END;
$$ LANGUAGE plpgsql;

-- 创建验证会员卡触发器函数
CREATE OR REPLACE FUNCTION validate_membership_card()
RETURNS TRIGGER AS $$
BEGIN
  -- 如果是新卡或更改了卡类型
  IF TG_OP = 'INSERT' OR OLD.card_type != NEW.card_type THEN
    -- 检查是否已有有效卡
    IF NOT check_valid_cards(NEW.member_id, NEW.card_type, NEW.id) THEN
      RAISE EXCEPTION '会员已有有效的%类型会员卡', NEW.card_type;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 创建会员卡验证触发器
DROP TRIGGER IF EXISTS membership_card_validation_trigger ON membership_cards;
CREATE TRIGGER membership_card_validation_trigger
  BEFORE INSERT OR UPDATE ON membership_cards
  FOR EACH ROW
  EXECUTE FUNCTION validate_membership_card();

-- 修复现有数据
DO $$
DECLARE
  v_member RECORD;
  v_latest_card_id UUID;
BEGIN
  -- 遍历所有会员
  FOR v_member IN SELECT DISTINCT member_id FROM membership_cards LOOP
    -- 处理团课卡，优先保留月卡
    SELECT id INTO v_latest_card_id
    FROM membership_cards
    WHERE member_id = v_member.member_id
      AND card_type = '团课'
      AND (valid_until IS NULL OR valid_until >= CURRENT_DATE)
      AND (
        (card_category = '课时卡' AND remaining_group_sessions > 0) OR
        card_category = '月卡'
      )
    ORDER BY 
      CASE WHEN card_category = '月卡' THEN 0 ELSE 1 END,  -- 优先月卡
      valid_until DESC NULLS LAST,  -- 其次是有效期最长的
      created_at DESC  -- 最后是最新创建的
    LIMIT 1;

    -- 将其他有效团课卡标记为已过期
    IF v_latest_card_id IS NOT NULL THEN
      UPDATE membership_cards
      SET valid_until = CURRENT_DATE - INTERVAL '1 day'
      WHERE member_id = v_member.member_id
        AND card_type = '团课'
        AND id != v_latest_card_id
        AND (valid_until IS NULL OR valid_until >= CURRENT_DATE);
    END IF;

    -- 处理私教卡
    SELECT id INTO v_latest_card_id
    FROM membership_cards
    WHERE member_id = v_member.member_id
      AND card_type = '私教课'
      AND (valid_until IS NULL OR valid_until >= CURRENT_DATE)
      AND remaining_private_sessions > 0
    ORDER BY 
      valid_until DESC NULLS LAST,  -- 优先选择有效期最长的
      remaining_private_sessions DESC,  -- 其次是剩余课时最多的
      created_at DESC  -- 最后是最新创建的
    LIMIT 1;

    -- 将其他有效私教卡标记为已过期
    IF v_latest_card_id IS NOT NULL THEN
      UPDATE membership_cards
      SET valid_until = CURRENT_DATE - INTERVAL '1 day'
      WHERE member_id = v_member.member_id
        AND card_type = '私教课'
        AND id != v_latest_card_id
        AND (valid_until IS NULL OR valid_until >= CURRENT_DATE);
    END IF;
  END LOOP;
END;
$$;

-- 向下迁移 (回滚更改)
-- 这里不提供回滚脚本，因为数据已经被修改 