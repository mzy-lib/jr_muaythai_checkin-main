-- 更新签到验证逻辑，支持自动处理无有效会员卡的情况
CREATE OR REPLACE FUNCTION validate_check_in()
RETURNS TRIGGER AS $$
DECLARE
    v_member_id uuid;
    v_card_id uuid;
    v_debug_details jsonb;
BEGIN
    -- 设置时区
    SET TIME ZONE 'Asia/Bangkok';
    
    -- 获取会员ID
    v_member_id := NEW.member_id;
    
    -- 初始化调试信息
    v_debug_details := jsonb_build_object(
        'member_id', v_member_id,
        'check_in_date', NEW.check_in_date,
        'class_type', NEW.class_type
    );

    -- 查找有效的会员卡
    SELECT id INTO v_card_id
    FROM membership_cards mc
    WHERE mc.member_id = v_member_id
    AND mc.valid_until >= CURRENT_DATE
    AND (
        -- 团课卡验证
        (NEW.class_type IN ('morning', 'evening') AND mc.card_type = 'group'
         AND (
             -- 课时卡检查剩余次数
             (mc.card_category = 'sessions' AND mc.remaining_group_sessions > 0)
             OR
             -- 月卡检查每日次数限制
             (mc.card_category = 'monthly' AND (
                 (mc.card_subtype = 'single' AND (
                     SELECT COUNT(*) FROM check_ins ci 
                     WHERE ci.member_id = v_member_id 
                     AND ci.check_in_date = NEW.check_in_date
                     AND ci.is_extra = false
                 ) < 1)
                 OR
                 (mc.card_subtype = 'double' AND (
                     SELECT COUNT(*) FROM check_ins ci 
                     WHERE ci.member_id = v_member_id 
                     AND ci.check_in_date = NEW.check_in_date
                     AND ci.is_extra = false
                 ) < 2)
             ))
         ))
        OR
        -- 私教卡验证
        (NEW.class_type = 'private' AND mc.card_type = 'private'
         AND mc.remaining_private_sessions > 0)
    )
    ORDER BY mc.valid_until ASC
    LIMIT 1;

    -- 记录调试信息
    INSERT INTO debug_logs (function_name, message, details, member_id)
    VALUES (
        'validate_check_in',
        '会员卡验证结果',
        jsonb_build_object(
            'has_valid_card', v_card_id IS NOT NULL,
            'card_id', v_card_id,
            'check_details', v_debug_details
        ),
        v_member_id
    );

    -- 根据会员卡验证结果设置is_extra和card_id
    IF v_card_id IS NOT NULL THEN
        NEW.is_extra := false;
        NEW.card_id := v_card_id;
    ELSE
        NEW.is_extra := true;
        NEW.card_id := NULL;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 确保触发器正确设置
DROP TRIGGER IF EXISTS validate_check_in_trigger ON check_ins;
CREATE TRIGGER validate_check_in_trigger
    BEFORE INSERT ON check_ins
    FOR EACH ROW
    EXECUTE FUNCTION validate_check_in();

-- 更新权限
GRANT EXECUTE ON FUNCTION validate_check_in() TO anon, authenticated, service_role; 