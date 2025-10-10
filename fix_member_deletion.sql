-- 修复会员删除功能中的外键约束问题

-- 开始事务
BEGIN;

-- 1. 先删除现有的外键约束
ALTER TABLE check_in_logs
DROP CONSTRAINT check_in_logs_check_in_id_fkey;

-- 2. 重新创建外键约束，添加级联删除
ALTER TABLE check_in_logs
ADD CONSTRAINT check_in_logs_check_in_id_fkey
FOREIGN KEY (check_in_id)
REFERENCES check_ins(id)
ON DELETE CASCADE;

-- 3. 创建一个函数用于删除会员及其相关数据
CREATE OR REPLACE FUNCTION delete_member_cascade(p_member_id UUID)
RETURNS VOID AS $$
BEGIN
    -- 记录开始删除会员
    INSERT INTO debug_logs (function_name, message, details)
    VALUES ('delete_member_cascade', '开始删除会员及相关数据',
        jsonb_build_object(
            'member_id', p_member_id
        )
    );
    
    -- 删除会员的会员卡
    DELETE FROM membership_cards
    WHERE member_id = p_member_id;
    
    -- 删除会员的签到记录（会自动级联删除check_in_logs中的记录）
    DELETE FROM check_ins
    WHERE member_id = p_member_id;
    
    -- 最后删除会员记录
    DELETE FROM members
    WHERE id = p_member_id;
    
    -- 记录删除完成
    INSERT INTO debug_logs (function_name, message, details)
    VALUES ('delete_member_cascade', '会员及相关数据删除完成',
        jsonb_build_object(
            'member_id', p_member_id
        )
    );
EXCEPTION
    WHEN OTHERS THEN
        -- 记录删除失败
        INSERT INTO debug_logs (function_name, message, details)
        VALUES ('delete_member_cascade', '删除会员失败',
            jsonb_build_object(
                'member_id', p_member_id,
                'error', SQLERRM,
                'error_detail', SQLSTATE
            )
        );
        RAISE;
END;
$$ LANGUAGE plpgsql;

-- 授予函数执行权限
GRANT EXECUTE ON FUNCTION delete_member_cascade(UUID) TO anon, authenticated, service_role;

-- 4. 创建一个API函数用于前端调用
CREATE OR REPLACE FUNCTION public.delete_member(p_member_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    -- 调用级联删除函数
    PERFORM delete_member_cascade(p_member_id);
    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 授予API函数执行权限
GRANT EXECUTE ON FUNCTION public.delete_member(UUID) TO anon, authenticated, service_role;

-- 提交事务
COMMIT;

-- 添加使用说明
COMMENT ON FUNCTION delete_member_cascade(UUID) IS '级联删除会员及其相关数据，包括会员卡、签到记录和签到日志';
COMMENT ON FUNCTION public.delete_member(UUID) IS '删除会员的API函数，供前端调用'; 