CREATE OR REPLACE FUNCTION public.find_matching_card(p_member_id uuid, p_class_type text, p_trainer_id uuid)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
    v_card_id uuid;
    v_trainer_type text;
BEGIN
    -- 处理私教课
    IF p_class_type = 'private' THEN
        -- 1. Get the trainer_type from the trainer's profile.
        SELECT type INTO v_trainer_type FROM public.trainers WHERE id = p_trainer_id;

        -- If trainer not found or has no type, we cannot find a matching card.
        IF v_trainer_type IS NULL THEN
            RETURN NULL;
        END IF;

        -- 2. Find a valid private card that matches the member, class type, and trainer type.
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
    END IF;

    -- 处理团课 (morning, evening)
    IF p_class_type IN ('morning', 'evening') THEN
        -- 查找适用于团课的卡（课时卡或月卡）
        SELECT id INTO v_card_id
        FROM public.membership_cards
        WHERE
            member_id = p_member_id
            AND (
                -- 课时卡：团课类型且有剩余课时
                (card_type IN ('group', 'class', '团课')
                 AND card_category IN ('sessions', 'group', '课时卡')
                 AND remaining_group_sessions > 0)
                OR
                -- 月卡：团课类型且在有效期内
                (card_type IN ('group', 'class', '团课')
                 AND card_category IN ('monthly', 'unlimited', '月卡')
                 AND (valid_until IS NULL OR valid_until >= CURRENT_DATE))
            )
            AND (valid_until IS NULL OR valid_until >= CURRENT_DATE)
        ORDER BY
            -- 优先使用即将到期的卡
            valid_until ASC NULLS LAST,
            -- 其次优先使用课时卡（避免浪费月卡）
            CASE WHEN card_category IN ('sessions', 'group', '课时卡') THEN 1 ELSE 2 END
        LIMIT 1;

        RETURN v_card_id;
    END IF;

    -- 处理儿童团课
    IF p_class_type = 'kids group' OR p_class_type LIKE '%kids%' THEN
        -- 查找适用于儿童团课的卡（使用 remaining_kids_sessions 字段）
        SELECT id INTO v_card_id
        FROM public.membership_cards
        WHERE
            member_id = p_member_id
            AND (card_type = '儿童团课' OR card_type LIKE '%kids%')
            AND remaining_kids_sessions > 0
            AND (valid_until IS NULL OR valid_until >= CURRENT_DATE)
        ORDER BY valid_until ASC NULLS LAST
        LIMIT 1;

        RETURN v_card_id;
    END IF;

    -- 未匹配的课程类型
    RETURN NULL;
END;
$$;
