-- 修复额外签到计数的触发器
-- 创建于: 2024-12-26
-- 作者: Claude AI
-- 描述: 此脚本创建一个触发器，用于在签到记录被标记为额外签到时自动更新会员的额外签到计数

BEGIN;

-- 创建或替换触发器函数，用于更新会员的额外签到计数
CREATE OR REPLACE FUNCTION update_member_extra_checkins()
RETURNS TRIGGER AS $$
DECLARE
    v_old_is_extra BOOLEAN;
BEGIN
    -- 获取旧记录的is_extra值（如果是更新操作）
    IF TG_OP = 'UPDATE' THEN
        v_old_is_extra := OLD.is_extra;
    ELSE
        v_old_is_extra := FALSE;
    END IF;
    
    -- 记录调试信息
    INSERT INTO debug_logs (function_name, member_id, message, details)
    VALUES (
        'update_member_extra_checkins',
        NEW.member_id,
        '更新会员额外签到计数',
        jsonb_build_object(
            'operation', TG_OP,
            'old_is_extra', v_old_is_extra,
            'new_is_extra', NEW.is_extra
        )
    );
    
    -- 根据操作类型和is_extra的变化更新会员的额外签到计数
    IF TG_OP = 'INSERT' AND NEW.is_extra THEN
        -- 新增额外签到
        UPDATE members
        SET extra_check_ins = COALESCE(extra_check_ins, 0) + 1
        WHERE id = NEW.member_id;
        
    ELSIF TG_OP = 'UPDATE' THEN
        IF NOT v_old_is_extra AND NEW.is_extra THEN
            -- 从普通签到变为额外签到
            UPDATE members
            SET extra_check_ins = COALESCE(extra_check_ins, 0) + 1
            WHERE id = NEW.member_id;
            
        ELSIF v_old_is_extra AND NOT NEW.is_extra THEN
            -- 从额外签到变为普通签到
            UPDATE members
            SET extra_check_ins = GREATEST(COALESCE(extra_check_ins, 0) - 1, 0)
            WHERE id = NEW.member_id;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 删除已存在的触发器（如果有）
DROP TRIGGER IF EXISTS update_member_extra_checkins_trigger ON check_ins;

-- 创建新的触发器
CREATE TRIGGER update_member_extra_checkins_trigger
AFTER INSERT OR UPDATE OF is_extra ON check_ins
FOR EACH ROW
EXECUTE FUNCTION update_member_extra_checkins();

-- 创建一个函数用于修复现有数据中的额外签到计数
CREATE OR REPLACE FUNCTION fix_member_extra_checkins()
RETURNS VOID AS $$
DECLARE
    v_member_id UUID;
    v_actual_count INTEGER;
    v_current_count INTEGER;
    v_updated_count INTEGER := 0;
BEGIN
    -- 记录开始修复
    INSERT INTO debug_logs (function_name, message, details)
    VALUES (
        'fix_member_extra_checkins',
        '开始修复会员额外签到计数',
        jsonb_build_object('timestamp', NOW())
    );
    
    -- 遍历所有会员
    FOR v_member_id, v_current_count IN 
        SELECT id, COALESCE(extra_check_ins, 0) 
        FROM members
    LOOP
        -- 计算实际的额外签到次数
        SELECT COUNT(*) INTO v_actual_count
        FROM check_ins
        WHERE member_id = v_member_id AND is_extra = true;
        
        -- 如果计数不一致，则更新
        IF v_current_count != v_actual_count THEN
            UPDATE members
            SET extra_check_ins = v_actual_count
            WHERE id = v_member_id;
            
            v_updated_count := v_updated_count + 1;
            
            -- 记录更新信息
            INSERT INTO debug_logs (function_name, member_id, message, details)
            VALUES (
                'fix_member_extra_checkins',
                v_member_id,
                '修复会员额外签到计数',
                jsonb_build_object(
                    'old_count', v_current_count,
                    'new_count', v_actual_count,
                    'difference', v_actual_count - v_current_count
                )
            );
        END IF;
    END LOOP;
    
    -- 记录完成修复
    INSERT INTO debug_logs (function_name, message, details)
    VALUES (
        'fix_member_extra_checkins',
        '完成修复会员额外签到计数',
        jsonb_build_object(
            'updated_members', v_updated_count,
            'timestamp', NOW()
        )
    );
END;
$$ LANGUAGE plpgsql;

-- 执行修复函数
SELECT fix_member_extra_checkins();

-- 授予函数执行权限
GRANT EXECUTE ON FUNCTION update_member_extra_checkins() TO postgres, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION fix_member_extra_checkins() TO postgres, anon, authenticated, service_role;

COMMIT; 