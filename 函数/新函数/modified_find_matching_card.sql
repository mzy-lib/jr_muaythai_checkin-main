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

    -- 1. Get the trainer_type from the trainer's profile.
    SELECT type INTO v_trainer_type FROM public.trainers WHERE id = p_trainer_id;

    -- If trainer not found or has no type, we cannot find a matching card.
    IF v_trainer_type IS NULL THEN
        RETURN NULL;
    END IF;

    -- 2. Find a valid card that matches the member, class type, and trainer type.
    --    - The card must be active (valid_until is in the future or null).
    --    - The card must have remaining sessions.
    --    - The card's trainer_type must exactly match the session's trainer_type.
    --    - Prioritize the card that will expire soonest to use it first.
    SELECT id INTO v_card_id
    FROM public.membership_cards
    WHERE
        member_id = p_member_id
        AND card_type = '私教课' -- Corresponds to 'private' class type
        AND (
          -- The card's level must be sufficient for the trainer's level.
          -- A 'senior' card can be used for both 'senior' and 'jr' trainers.
          -- A 'jr' card can only be used for 'jr' trainers.
          (lower(trim(trainer_type)) = 'senior') OR
          (lower(trim(trainer_type)) = 'jr' AND lower(trim(v_trainer_type)) = 'jr')
        )
        AND (valid_until IS NULL OR valid_until >= CURRENT_DATE)
        AND remaining_private_sessions > 0
    ORDER BY valid_until ASC NULLS LAST -- Use the card that expires soonest first
    LIMIT 1;

    RETURN v_card_id;
END;
$$;
