-- 向上迁移 (应用更改)
-- 创建会员卡有效期管理函数

-- 创建设置会员卡有效期函数
CREATE OR REPLACE FUNCTION set_card_validity(
  p_card_id UUID,
  p_card_type TEXT,
  p_card_category TEXT,
  p_card_subtype TEXT
) RETURNS VOID AS $$
DECLARE
  v_valid_until DATE;
BEGIN
  -- 根据不同卡类型设置有效期
  v_valid_until := CASE
    -- 团课月卡：购买日起30天
    WHEN p_card_type = 'group' AND p_card_category = 'monthly' THEN
      CURRENT_DATE + INTERVAL '30 days'
    -- 团课10次卡：购买日起3个月
    WHEN p_card_type = 'group' AND p_card_category = 'session' AND p_card_subtype = 'ten_classes' THEN
      CURRENT_DATE + INTERVAL '3 months'
    -- 私教10次卡：购买日起1个月
    WHEN p_card_type = 'private' AND p_card_subtype = 'ten_classes' THEN
      CURRENT_DATE + INTERVAL '1 month'
    -- 其他卡：无到期限制
    ELSE NULL
  END;
  
  -- 更新会员卡有效期
  UPDATE membership_cards
  SET valid_until = v_valid_until
  WHERE id = p_card_id;
  
  -- 记录日志
  IF current_setting('app.environment', true) = 'development' THEN
    INSERT INTO debug_logs (function_name, message, details)
    VALUES ('set_card_validity', '设置会员卡有效期', 
      jsonb_build_object(
        'card_id', p_card_id,
        'card_type', p_card_type,
        'card_category', p_card_category,
        'card_subtype', p_card_subtype,
        'valid_until', v_valid_until
      )
    );
  END IF;
END;
$$ LANGUAGE plpgsql;

-- 创建会员卡有效期触发器函数
CREATE OR REPLACE FUNCTION trigger_set_card_validity() 
RETURNS TRIGGER AS $$
BEGIN
  PERFORM set_card_validity(NEW.id, NEW.card_type, NEW.card_category, NEW.card_subtype);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 创建会员卡有效期触发器
CREATE TRIGGER set_card_validity_trigger
AFTER INSERT ON membership_cards
FOR EACH ROW
EXECUTE FUNCTION trigger_set_card_validity();

-- 向下迁移 (回滚更改)
-- DROP TRIGGER IF EXISTS set_card_validity_trigger ON membership_cards;
-- DROP FUNCTION IF EXISTS trigger_set_card_validity();
-- DROP FUNCTION IF EXISTS set_card_validity(UUID, TEXT, TEXT, TEXT); 