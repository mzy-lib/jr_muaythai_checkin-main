-- Function: find_matching_card
-- Description: Finds the most appropriate valid membership card for a check-in.
-- Parameters:
--   p_member_id: The member's UUID.
--   p_class_type: The type of class ('private', 'group', etc.).
--   p_trainer_id: The trainer's UUID for the current session.
-- Returns: The UUID of the best matching card, or NULL if no suitable card is found.

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
    --    - The card's trainer_type must match the session's trainer_type.
    --    - Prioritize the card that will expire soonest to use it first.
    SELECT id INTO v_card_id
    FROM public.membership_cards
    WHERE
        member_id = p_member_id
        AND card_type = '私教课' -- Corresponds to 'private' class type
        AND trainer_type = v_trainer_type
        AND (valid_until IS NULL OR valid_until >= CURRENT_DATE)
        AND remaining_private_sessions > 0
    ORDER BY valid_until ASC NULLS LAST -- Use the card that expires soonest first
    LIMIT 1;

    RETURN v_card_id;
END;
$$;
