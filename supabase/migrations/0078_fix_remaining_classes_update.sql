BEGIN;

-- 重新创建process_check_in函数
CREATE OR REPLACE FUNCTION process_check_in()
RETURNS TRIGGER AS $$
DECLARE
    v_membership membership_type;
    v_is_new_member boolean;
    v_remaining_classes integer;
    v_old_remaining_classes integer;
    v_new_remaining_classes integer;
BEGIN
    -- 获取会员信息
    SELECT membership, is_new_member, remaining_classes 
    INTO v_membership, v_is_new_member, v_remaining_classes
    FROM members 
    WHERE id = NEW.member_id;
    
    -- 记录初始状态
    INSERT INTO debug_logs (function_name, member_id, message, details) 
    VALUES (
        'process_check_in',
        NEW.member_id,
        '开始处理签到',
        jsonb_build_object(
            'membership', v_membership,
            'is_new_member', v_is_new_member,
            'remaining_classes', v_remaining_classes,
            'is_extra', NEW.is_extra
        )
    );

    v_old_remaining_classes := v_remaining_classes;
    
    -- 处理课时卡扣减
    IF NOT NEW.is_extra AND v_membership = 'ten_classes' THEN
        -- 检查是否还有剩余课时
        IF v_remaining_classes > 0 THEN
            -- 扣减课时
            UPDATE members 
            SET remaining_classes = remaining_classes - 1
            WHERE id = NEW.member_id
            RETURNING remaining_classes INTO v_new_remaining_classes;
            
            INSERT INTO debug_logs (function_name, member_id, message, details) 
            VALUES (
                'process_check_in',
                NEW.member_id,
                '课时扣减完成',
                jsonb_build_object(
                    'old_remaining_classes', v_old_remaining_classes,
                    'new_remaining_classes', v_new_remaining_classes
                )
            );
            
            -- 如果课时用完，设置membership为null
            IF v_new_remaining_classes = 0 THEN
                UPDATE members 
                SET membership = null
                WHERE id = NEW.member_id;
                
                INSERT INTO debug_logs (function_name, member_id, message, details) 
                VALUES (
                    'process_check_in',
                    NEW.member_id,
                    '课时已用完，清除会员类型',
                    jsonb_build_object('membership', null)
                );
            END IF;
        ELSE
            -- 课时不足，将签到标记为extra
            NEW.is_extra := true;
            
            INSERT INTO debug_logs (function_name, member_id, message, details) 
            VALUES (
                'process_check_in',
                NEW.member_id,
                '课时不足，转为extra签到',
                jsonb_build_object('is_extra', true)
            );
        END IF;
    END IF;

    -- 更新新会员状态
    IF v_is_new_member = true THEN
        UPDATE members 
        SET is_new_member = false
        WHERE id = NEW.member_id;
        
        INSERT INTO debug_logs (function_name, member_id, message, details) 
        VALUES (
            'process_check_in',
            NEW.member_id,
            '更新新会员状态',
            jsonb_build_object(
                'old_status', true,
                'new_status', false
            )
        );
    END IF;

    -- 更新extra签到计数
    IF NEW.is_extra THEN
        UPDATE members 
        SET extra_check_ins = extra_check_ins + 1
        WHERE id = NEW.member_id;
        
        INSERT INTO debug_logs (function_name, member_id, message, details) 
        VALUES (
            'process_check_in',
            NEW.member_id,
            '增加extra签到次数',
            jsonb_build_object('is_extra', true)
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 删除已存在的trigger
DROP TRIGGER IF EXISTS process_check_in_trigger ON check_ins;

-- 创建新的trigger
CREATE TRIGGER process_check_in_trigger
    BEFORE INSERT ON check_ins
    FOR EACH ROW
    EXECUTE FUNCTION process_check_in();

COMMIT; 