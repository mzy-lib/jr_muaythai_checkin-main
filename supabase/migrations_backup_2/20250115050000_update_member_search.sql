-- 更新会员查找和注册逻辑

-- 1. 添加姓名+邮箱组合的唯一约束
ALTER TABLE members
DROP CONSTRAINT IF EXISTS unique_name_email;

ALTER TABLE members
ADD CONSTRAINT unique_name_email UNIQUE (name, email);

-- 2. 更新find_member_for_checkin函数
DROP FUNCTION IF EXISTS public.find_member_for_checkin(text, text);

CREATE OR REPLACE FUNCTION public.find_member_for_checkin(
    p_name text,
    p_email text
)
RETURNS TABLE(
    member_id uuid,
    is_new boolean
)
LANGUAGE plpgsql
AS $function$
DECLARE
    v_normalized_name text;
    v_normalized_email text;
BEGIN
    -- Input validation
    IF TRIM(p_name) = '' THEN
        RAISE EXCEPTION 'Name cannot be empty';
    END IF;

    IF TRIM(p_email) = '' THEN
        RAISE EXCEPTION 'Email cannot be empty';
    END IF;

    -- Normalize inputs
    v_normalized_name := LOWER(TRIM(p_name));
    v_normalized_email := LOWER(TRIM(p_email));

    -- 使用姓名+邮箱组合查找会员
    RETURN QUERY
    SELECT
        m.id,
        m.is_new_member
    FROM members m
    WHERE LOWER(TRIM(m.name)) = v_normalized_name
    AND LOWER(TRIM(m.email)) = v_normalized_email;

    -- 如果没有找到记录，返回null和true表示新会员
    IF NOT FOUND THEN
        RETURN QUERY SELECT NULL::uuid, true::boolean;
    END IF;
END;
$function$;

-- 3. 更新register_new_member函数
CREATE OR REPLACE FUNCTION public.register_new_member(
    p_name text,
    p_email text,
    p_class_type class_type
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_member_id uuid;
    v_check_in_id uuid;
    v_existing_member RECORD;
BEGIN
    -- Input validation
    IF NOT validate_member_name(p_name, p_email) THEN
        RAISE EXCEPTION '无效的姓名格式。Invalid name format.'
            USING HINT = 'invalid_name';
    END IF;

    -- 检查姓名+邮箱组合是否存在
    SELECT id, email, is_new_member 
    INTO v_existing_member
    FROM members
    WHERE LOWER(TRIM(name)) = LOWER(TRIM(p_name))
    AND LOWER(TRIM(email)) = LOWER(TRIM(p_email))
    FOR UPDATE;

    IF FOUND THEN
        RAISE NOTICE 'Member already exists with this name and email: name=%, email=%', p_name, p_email;
        RAISE EXCEPTION '该姓名和邮箱组合已被注册。This name and email combination is already registered.'
            USING HINT = 'member_exists';
    END IF;

    -- 创建新会员
    INSERT INTO members (
        name,
        email,
        is_new_member,
        created_at
    ) VALUES (
        TRIM(p_name),
        TRIM(p_email),
        true,
        NOW()
    ) RETURNING id INTO v_member_id;

    RAISE NOTICE 'New member created: id=%, name=%, email=%', v_member_id, p_name, p_email;

    -- 创建初始签到记录
    INSERT INTO check_ins (
        member_id,
        class_type,
        check_in_date,
        is_extra,
        created_at
    ) VALUES (
        v_member_id,
        p_class_type,
        CURRENT_DATE,
        true,
        NOW()
    ) RETURNING id INTO v_check_in_id;

    RAISE NOTICE 'Initial check-in created: id=%, member_id=%, class_type=%', 
        v_check_in_id, v_member_id, p_class_type;

    -- 返回成功响应
    RETURN json_build_object(
        'success', true,
        'member_id', v_member_id,
        'check_in_id', v_check_in_id
    );

EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'Unique violation error: name=%, email=%', p_name, p_email;
        RAISE EXCEPTION '该姓名和邮箱组合已被注册。This name and email combination is already registered.'
            USING HINT = 'member_exists';
    WHEN OTHERS THEN
        RAISE NOTICE 'Unexpected error in register_new_member: %', SQLERRM;
        RAISE;
END;
$function$;

-- 更新权限
GRANT EXECUTE ON FUNCTION public.find_member_for_checkin(text, text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.register_new_member(text, text, class_type) TO anon, authenticated, service_role; 