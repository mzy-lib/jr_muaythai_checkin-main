BEGIN;

-- 重新创建validate_check_in函数
CREATE OR REPLACE FUNCTION validate_check_in()
RETURNS TRIGGER AS $$
DECLARE
    v_member RECORD;
    v_daily_check_ins INTEGER;
BEGIN
    -- 获取会员信息
    SELECT * INTO v_member FROM members WHERE id = NEW.member_id;
    
    -- 记录初始状态
    INSERT INTO debug_logs (function_name, member_id, message, details) 
    VALUES (
        'validate_check_in',
        NEW.member_id,
        '开始验证签到',
        jsonb_build_object(
            'membership', v_member.membership,
            'membership_expiry', v_member.membership_expiry,
            'remaining_classes', v_member.remaining_classes
        )
    );
    
    -- 获取当天该会员的签到次数
    SELECT COUNT(*) INTO v_daily_check_ins 
    FROM check_ins 
    WHERE member_id = NEW.member_id 
    AND DATE(check_in_date) = DATE(NEW.check_in_date);
    
    -- 设置is_extra标志
    IF v_member.membership = 'monthly' THEN
        -- 月卡会员
        IF v_member.membership_expiry < CURRENT_DATE THEN
            -- 过期月卡
            NEW.is_extra := true;
            
            INSERT INTO debug_logs (function_name, member_id, message, details) 
            VALUES (
                'validate_check_in',
                NEW.member_id,
                '月卡已过期，标记为extra签到',
                jsonb_build_object(
                    'membership_expiry', v_member.membership_expiry,
                    'current_date', CURRENT_DATE,
                    'is_extra', true
                )
            );
        ELSIF v_daily_check_ins >= 1 THEN
            -- 当天已有签到
            NEW.is_extra := true;
            
            INSERT INTO debug_logs (function_name, member_id, message, details) 
            VALUES (
                'validate_check_in',
                NEW.member_id,
                '当天已有签到，标记为extra签到',
                jsonb_build_object(
                    'daily_check_ins', v_daily_check_ins,
                    'is_extra', true
                )
            );
        ELSE
            NEW.is_extra := false;
            
            INSERT INTO debug_logs (function_name, member_id, message, details) 
            VALUES (
                'validate_check_in',
                NEW.member_id,
                '月卡有效，正常签到',
                jsonb_build_object('is_extra', false)
            );
        END IF;
    ELSIF v_member.membership = 'class_hours' THEN
        -- 课时卡会员
        IF v_member.remaining_classes <= 0 THEN
            -- 课时不足
            NEW.is_extra := true;
            
            INSERT INTO debug_logs (function_name, member_id, message, details) 
            VALUES (
                'validate_check_in',
                NEW.member_id,
                '课时不足，标记为extra签到',
                jsonb_build_object(
                    'remaining_classes', v_member.remaining_classes,
                    'is_extra', true
                )
            );
        ELSIF v_daily_check_ins >= 1 THEN
            -- 当天已有签到
            NEW.is_extra := true;
            
            INSERT INTO debug_logs (function_name, member_id, message, details) 
            VALUES (
                'validate_check_in',
                NEW.member_id,
                '当天已有签到，标记为extra签到',
                jsonb_build_object(
                    'daily_check_ins', v_daily_check_ins,
                    'is_extra', true
                )
            );
        ELSE
            NEW.is_extra := false;
            
            INSERT INTO debug_logs (function_name, member_id, message, details) 
            VALUES (
                'validate_check_in',
                NEW.member_id,
                '课时卡有效，正常签到',
                jsonb_build_object(
                    'remaining_classes', v_member.remaining_classes,
                    'is_extra', false
                )
            );
        END IF;
    ELSE
        -- 其他情况均为额外签到
        NEW.is_extra := true;
        
        INSERT INTO debug_logs (function_name, member_id, message, details) 
        VALUES (
            'validate_check_in',
            NEW.member_id,
            '无有效会员卡，标记为extra签到',
            jsonb_build_object(
                'membership', v_member.membership,
                'is_extra', true
            )
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 删除已存在的trigger
DROP TRIGGER IF EXISTS validate_check_in_trigger ON check_ins;

-- 创建新的trigger
CREATE TRIGGER validate_check_in_trigger
    BEFORE INSERT ON check_ins
    FOR EACH ROW
    EXECUTE FUNCTION validate_check_in();

COMMIT; 