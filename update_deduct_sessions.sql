CREATE OR REPLACE FUNCTION public.deduct_membership_sessions(
    p_card_id uuid,
    p_class_type text,
    p_is_private boolean,
    p_is_1v2 boolean
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_card RECORD;
  v_is_kids_group boolean;
  v_deduct_sessions INTEGER;
BEGIN
  -- Lock the card record for update
  SELECT * INTO v_card 
  FROM membership_cards 
  WHERE id = p_card_id 
  FOR UPDATE;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION '会员卡不存在';
  END IF;

  v_is_kids_group := (p_class_type LIKE '%kids%' OR p_class_type LIKE '%儿童%');

  -- Private Class Deduction
  IF p_is_private AND v_card.card_type = '私教课' THEN
    v_deduct_sessions := 1; -- 1v1 and 1v2 both deduct 1 session
    
    IF v_card.remaining_private_sessions < v_deduct_sessions THEN
      RAISE EXCEPTION '私教课时不足';
    END IF;
    
    UPDATE membership_cards 
    SET remaining_private_sessions = remaining_private_sessions - v_deduct_sessions
    WHERE id = p_card_id;
  
  -- Kids Group Class Deduction
  ELSIF v_is_kids_group AND (v_card.card_type = '儿童团课' OR v_card.card_type LIKE '%kids%') THEN
    v_deduct_sessions := 1;
    
    IF v_card.remaining_kids_sessions IS NULL OR v_card.remaining_kids_sessions < v_deduct_sessions THEN
      RAISE EXCEPTION '儿童团课课时不足';
    END IF;
    
    UPDATE membership_cards 
    SET remaining_kids_sessions = remaining_kids_sessions - v_deduct_sessions
    WHERE id = p_card_id;
  
  -- Regular Group Class Deduction
  ELSIF NOT p_is_private AND NOT v_is_kids_group AND v_card.card_type = '团课' AND v_card.card_category = '课时卡' THEN
    v_deduct_sessions := 1;
    
    IF v_card.remaining_group_sessions IS NULL OR v_card.remaining_group_sessions < v_deduct_sessions THEN
      RAISE EXCEPTION '团课课时不足';
    END IF;
    
    UPDATE membership_cards 
    SET remaining_group_sessions = remaining_group_sessions - v_deduct_sessions
    WHERE id = p_card_id;
  
  END IF;

END;
$$;
