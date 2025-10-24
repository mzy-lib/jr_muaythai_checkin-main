-- Deploy Script for Check-in Logic
-- Version: 2025-10-24
-- This script drops and recreates all necessary functions to ensure consistency.

-- 1. Drop existing functions to ensure a clean slate
DROP FUNCTION IF EXISTS public.find_matching_card(uuid, text, uuid);
DROP FUNCTION IF EXISTS public.check_card_validity(uuid, uuid, date, text, uuid);
DROP FUNCTION IF EXISTS public.handle_check_in(uuid, uuid, text, date, uuid, boolean, text, text, text);

-- 2. Recreate find_matching_card function
CREATE OR REPLACE FUNCTION public.find_matching_card(p_member_id uuid, p_class_type text, p_trainer_id uuid)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
    v_card_id uuid;
    v_trainer_type text;
BEGIN
    -- This function is only for private classes, as they are linked to trainers.
    IF p_class_type != 'private' THEN
        RETURN NULL;
    END IF;

    -- Get the trainer_type from the trainer's profile.
    SELECT type INTO v_trainer_type FROM public.trainers WHERE id = p_trainer_id;

    -- If trainer not found or has no type, we cannot find a matching card.
    IF v_trainer_type IS NULL THEN
        RETURN NULL;
    END IF;

    -- Find a valid card that strictly matches the member, class type, and trainer type.
    SELECT id INTO v_card_id
    FROM public.membership_cards
    WHERE
        member_id = p_member_id
        AND card_type = '私教课'
        AND lower(trim(trainer_type)) = lower(trim(v_trainer_type)) -- Strict matching
        AND (valid_until IS NULL OR valid_until >= CURRENT_DATE)
        AND remaining_private_sessions > 0
    ORDER BY valid_until ASC NULLS LAST -- Use the card that expires soonest first
    LIMIT 1;

    RETURN v_card_id;
END;
$$;

-- 3. Recreate check_card_validity function
CREATE OR REPLACE FUNCTION public.check_card_validity(p_card_id uuid, p_member_id uuid, p_check_in_date date, p_class_type text, p_trainer_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_card RECORD;
  v_class_type_enum class_type;
  v_is_private boolean;
  v_trainer_type text;
  v_card_trainer_type text;
BEGIN
  -- Convert class type
  BEGIN
    v_class_type_enum := p_class_type::class_type;
    v_is_private := (v_class_type_enum = 'private'::class_type);
  EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('is_valid', false, 'reason', '无效的课程类型');
  END;

  -- Get card info
  SELECT * INTO v_card FROM membership_cards WHERE id = p_card_id FOR UPDATE;

  -- Check if card exists
  IF NOT FOUND THEN
    RETURN jsonb_build_object('is_valid', false, 'reason', '会员卡不存在');
  END IF;

  -- Check if card belongs to the member
  IF v_card.member_id != p_member_id THEN
    RETURN jsonb_build_object('is_valid', false, 'reason', '会员卡不属于该会员');
  END IF;

  -- Check card expiration
  IF v_card.valid_until IS NOT NULL AND v_card.valid_until < p_check_in_date THEN
    RETURN jsonb_build_object('is_valid', false, 'reason', '会员卡已过期');
  END IF;

  -- Check if card type matches class type
  IF (v_card.card_type = '私教课' AND NOT v_is_private) OR
     (v_card.card_type = '团课' AND v_is_private) THEN
    RETURN jsonb_build_object('is_valid', false, 'reason', '卡类型不匹配课程类型');
  END IF;

  -- Perform strict trainer type matching
  IF p_trainer_id IS NOT NULL THEN
    SELECT lower(trim(type)) INTO v_trainer_type FROM trainers WHERE id = p_trainer_id;

    IF v_trainer_type IS NULL THEN
        RETURN jsonb_build_object('is_valid', false, 'reason', '签到教练信息不存在或类型未知');
    END IF;

    v_card_trainer_type := lower(trim(v_card.trainer_type));

    IF v_card_trainer_type != v_trainer_type THEN
        RETURN jsonb_build_object('is_valid', false, 'reason', '卡等级(' || v_card_trainer_type || ')与教练等级(' || v_trainer_type || ')不匹配');
    END IF;
  END IF;

  -- Check for remaining sessions
  IF (v_card.card_type = '私教课' AND (v_card.remaining_private_sessions IS NULL OR v_card.remaining_private_sessions <= 0)) OR
     (v_card.card_type = '团课' AND (v_card.remaining_group_sessions IS NULL OR v_card.remaining_group_sessions <= 0)) THEN
    RETURN jsonb_build_object('is_valid', false, 'reason', '课时不足');
  END IF;

  -- All checks passed, card is valid
  RETURN jsonb_build_object('is_valid', true);
END;
$$;

-- 4. Recreate handle_check_in function
CREATE OR REPLACE FUNCTION public.handle_check_in(p_member_id uuid, p_card_id uuid, p_class_type text, p_check_in_date date, p_trainer_id uuid, p_is_1v2 boolean, p_time_slot text, p_name text, p_email text)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_check_in_id uuid;
  v_is_extra boolean := true;
  v_class_type_enum class_type;
  v_is_private boolean;
  v_message text;
  v_validity jsonb;
  v_matched_card_id uuid := NULL;
BEGIN
  -- Precondition checks
  BEGIN
    v_class_type_enum := p_class_type::class_type;
    v_is_private := (v_class_type_enum = 'private'::class_type);
  EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', '无效的课程类型: ' || p_class_type);
  END;

  IF p_time_slot IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', '请选择有效的时间段');
  END IF;

  IF check_duplicate_check_in(p_member_id, p_check_in_date, p_class_type, p_time_slot) THEN
    RETURN jsonb_build_object('success', false, 'message', '今天已经在这个时段签到过了', 'isDuplicate', true);
  END IF;

  -- Find the correct card for the session
  IF v_is_private THEN
    v_matched_card_id := find_matching_card(p_member_id, p_class_type, p_trainer_id);
  ELSE
    v_matched_card_id := p_card_id;
  END IF;

  -- Validate the found card
  IF v_matched_card_id IS NOT NULL THEN
    v_validity := check_card_validity(v_matched_card_id, p_member_id, p_check_in_date, p_class_type, p_trainer_id);
    
    IF (v_validity->>'is_valid')::boolean THEN
      v_is_extra := false;
      v_message := '签到成功';
    ELSE
      v_message := v_validity->>'reason';
      -- Critical Fix: If validation fails, ensure the card ID is nullified to guarantee an extra check-in.
      v_matched_card_id := NULL;
    END IF;
  ELSE
    v_message := '未找到可用的会员卡';
  END IF;
  
  -- Insert check-in record
  INSERT INTO check_ins(member_id, card_id, class_type, check_in_date, trainer_id, is_1v2, is_extra, time_slot, is_private)
  VALUES (p_member_id, v_matched_card_id, v_class_type_enum, p_check_in_date, p_trainer_id, p_is_1v2, v_is_extra, p_time_slot, v_is_private)
  RETURNING id INTO v_check_in_id;
  
  -- Deduct session only for normal check-ins
  IF NOT v_is_extra THEN
    PERFORM deduct_membership_sessions(v_matched_card_id, p_class_type, v_is_private, p_is_1v2);
  END IF;
  
  -- Update member's last check-in date
  UPDATE members SET last_check_in_date = p_check_in_date WHERE id = p_member_id;
  
  -- Return result
  RETURN jsonb_build_object(
    'success', true,
    'message', v_message,
    'isExtra', v_is_extra,
    'checkInId', v_check_in_id
  );

EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM, 'error', SQLSTATE);
END;
$$;
