CREATE OR REPLACE FUNCTION public.check_valid_cards(p_member_id uuid, p_card_type text, p_trainer_type text, p_current_card_id uuid)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
  v_card_exists BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM public.membership_cards
    WHERE member_id = p_member_id
      AND card_type = p_card_type
      -- 核心修改：如果是私教课，则额外匹配教练类型 (安全处理NULL)
      AND (
          p_card_type != '私教课' OR
          trainer_type IS NOT DISTINCT FROM p_trainer_type
      )
      AND id != COALESCE(p_current_card_id, '00000000-0000-0000-0000-000000000000'::UUID)
      AND (valid_until IS NULL OR valid_until >= CURRENT_DATE)
      AND (
        (card_type = '团课' AND (
          (card_category = '课时卡' AND remaining_group_sessions > 0) OR
          card_category = '月卡'
        )) OR
        (card_type = '私教课' AND remaining_private_sessions > 0)
      )
  ) INTO v_card_exists;

  RETURN NOT v_card_exists; -- 如果卡存在 (v_card_exists=true)，则返回false
END;
$$;
