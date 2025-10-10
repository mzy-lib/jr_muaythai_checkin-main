                                                        pg_get_functiondef                                                        
----------------------------------------------------------------------------------------------------------------------------------
 CREATE OR REPLACE FUNCTION public.check_card_validity(p_card_id uuid, p_member_id uuid, p_class_type text, p_check_in_date date)+
  RETURNS boolean                                                                                                                +
  LANGUAGE plpgsql                                                                                                               +
 AS $function$                                                                                                                   +
 DECLARE                                                                                                                         +
   v_card RECORD;                                                                                                                +
 BEGIN                                                                                                                           +
   SELECT * INTO v_card FROM membership_cards WHERE id = p_card_id;                                                              +
                                                                                                                                 +
   IF NOT FOUND THEN                                                                                                             +
     RETURN FALSE;                                                                                                               +
   END IF;                                                                                                                       +
                                                                                                                                 +
   IF v_card.member_id != p_member_id THEN                                                                                       +
     RETURN FALSE;                                                                                                               +
   END IF;                                                                                                                       +
                                                                                                                                 +
   -- 根据实际情况调整类型比较                                                                                                   +
   IF (v_card.card_type = 'group' AND p_class_type = 'private') OR                                                               +
      (v_card.card_type = 'private' AND p_class_type != 'private') THEN                                                          +
     RETURN FALSE;                                                                                                               +
   END IF;                                                                                                                       +
                                                                                                                                 +
   IF v_card.valid_until IS NOT NULL AND v_card.valid_until < p_check_in_date THEN                                               +
     RETURN FALSE;                                                                                                               +
   END IF;                                                                                                                       +
                                                                                                                                 +
   IF v_card.card_type = 'group' AND v_card.card_category = 'session' AND                                                        +
      (v_card.remaining_group_sessions IS NULL OR v_card.remaining_group_sessions <= 0) THEN                                     +
     RETURN FALSE;                                                                                                               +
   END IF;                                                                                                                       +
                                                                                                                                 +
   IF v_card.card_type = 'private' AND                                                                                           +
      (v_card.remaining_private_sessions IS NULL OR v_card.remaining_private_sessions <= 0) THEN                                 +
     RETURN FALSE;                                                                                                               +
   END IF;                                                                                                                       +
                                                                                                                                 +
   RETURN TRUE;                                                                                                                  +
 END;                                                                                                                            +
 $function$                                                                                                                      +
 
(1 row)

