-- 向上迁移 (应用更改)
-- 创建辅助验证函数
CREATE OR REPLACE FUNCTION check_member_exists(p_member_id UUID) 
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (SELECT 1 FROM members WHERE id = p_member_id);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION check_duplicate_check_in(p_member_id UUID, p_date DATE, p_class_type TEXT) 
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM check_ins 
    WHERE member_id = p_member_id 
    AND check_in_date = p_date 
    AND class_type = p_class_type
  );
END;
$$ LANGUAGE plpgsql;

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

-- 向下迁移 (回滚更改)
-- DROP FUNCTION IF EXISTS check_card_validity(UUID, UUID, TEXT, DATE);
-- DROP FUNCTION IF EXISTS check_duplicate_check_in(UUID, DATE, TEXT);
-- DROP FUNCTION IF EXISTS check_member_exists(UUID); 