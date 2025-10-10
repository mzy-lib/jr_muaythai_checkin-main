-- 更新签到处理逻辑，支持自动处理无有效会员卡的情况
CREATE OR REPLACE FUNCTION process_check_in()
RETURNS TRIGGER AS $$
DECLARE
    v_member_id uuid;
    v_card_id uuid;
    v_debug_details jsonb;
BEGIN
    -- 设置时区
    SET TIME ZONE 'Asia/Bangkok';
    
    -- 获取会员ID和卡ID
    v_member_id := NEW.member_id;
    v_card_id := NEW.card_id;
    
    -- 初始化调试信息
    v_debug_details := jsonb_build_object(
        'member_id', v_member_id,
        'check_in_date', NEW.check_in_date,
        'class_type', NEW.class_type,
        'is_extra', NEW.is_extra,
        'card_id', v_card_id
    );

    -- 处理正常签到（有效会员卡）
    IF NOT NEW.is_extra THEN
        -- 更新会员卡剩余次数
        UPDATE membership_cards
        SET 
            remaining_group_sessions = CASE 
                WHEN card_type = 'group' AND card_category = 'sessions' 
                AND NEW.class_type IN ('morning', 'evening')
                THEN remaining_group_sessions - 1
                ELSE remaining_group_sessions
            END,
            remaining_private_sessions = CASE 
                WHEN card_type = 'private' AND NEW.class_type = 'private'
                THEN remaining_private_sessions - 1
                ELSE remaining_private_sessions
            END
        WHERE id = v_card_id;

        -- 记录调试信息
        INSERT INTO debug_logs (function_name, message, details, member_id)
        VALUES (
            'process_check_in',
            '正常签到处理完成',
            jsonb_build_object(
                'action', '更新会员卡剩余次数',
                'check_details', v_debug_details
            ),
            v_member_id
        );
    ELSE
        -- 更新会员的额外签到统计
        UPDATE members
        SET extra_check_ins = COALESCE(extra_check_ins, 0) + 1
        WHERE id = v_member_id;

        -- 记录调试信息
        INSERT INTO debug_logs (function_name, message, details, member_id)
        VALUES (
            'process_check_in',
            '额外签到处理完成',
            jsonb_build_object(
                'action', '更新额外签到统计',
                'check_details', v_debug_details
            ),
            v_member_id
        );
    END IF;

    -- 更新会员最后签到日期
    UPDATE members
    SET last_check_in_date = NEW.check_in_date
    WHERE id = v_member_id;

    -- 记录最终调试信息
    INSERT INTO debug_logs (function_name, message, details, member_id)
    VALUES (
        'process_check_in',
        '签到处理完成',
        jsonb_build_object(
            'final_status', '成功',
            'check_details', v_debug_details
        ),
        v_member_id
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 确保触发器正确设置
DROP TRIGGER IF EXISTS process_check_in_trigger ON check_ins;
CREATE TRIGGER process_check_in_trigger
    AFTER INSERT ON check_ins
    FOR EACH ROW
    EXECUTE FUNCTION process_check_in();

-- 更新权限
GRANT EXECUTE ON FUNCTION process_check_in() TO anon, authenticated, service_role; 