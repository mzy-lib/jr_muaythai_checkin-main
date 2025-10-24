CREATE OR REPLACE FUNCTION public.find_matching_card(
    p_member_id uuid,
    p_class_type text,
    p_trainer_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
    v_card_id uuid;
    v_trainer_type text;
BEGIN
    -- This function is only for private classes.
    IF p_class_type != 'private' THEN
        RETURN NULL;
    END IF;

    -- 1. Get the trainer's type from their profile, and standardize it.
    SELECT lower(trim(type)) INTO v_trainer_type FROM public.trainers WHERE id = p_trainer_id;

    -- If trainer not found or has no type, we cannot find a matching card.
    IF v_trainer_type IS NULL THEN
        RETURN NULL;
    END IF;

    -- 2. Find a valid card that matches the member, class type, and STANDARDIZED trainer type.
    SELECT id INTO v_card_id
    FROM public.membership_cards
    WHERE
        member_id = p_member_id
        AND card_type = '私教课'
        -- CRITICAL FIX: Standardize the card's trainer_type before comparing
        AND lower(trim(trainer_type)) = v_trainer_type
        AND (valid_until IS NULL OR valid_until >= CURRENT_DATE)
        AND remaining_private_sessions > 0
    ORDER BY valid_until ASC NULLS LAST -- Use the card that expires soonest first
    LIMIT 1;

    RETURN v_card_id;
END;
$$;
