BEGIN;

-- 先修改枚举类型值
ALTER TYPE membership_type RENAME TO membership_type_old;

CREATE TYPE membership_type AS ENUM (
    'single_class',
    'two_classes',
    'ten_classes',
    'single_monthly',
    'double_monthly'
);

-- 更新表中的数据
ALTER TABLE members 
    ALTER COLUMN membership TYPE membership_type 
    USING (
        CASE membership::text
            WHEN 'single_daily_monthly' THEN 'single_monthly'::membership_type
            WHEN 'double_daily_monthly' THEN 'double_monthly'::membership_type
            ELSE membership::text::membership_type
        END
    );

-- 使用CASCADE删除旧类型及其依赖
DROP TYPE membership_type_old CASCADE;

-- 重新创建search_members函数
CREATE OR REPLACE FUNCTION search_members(search_query text)
RETURNS TABLE (
    id uuid,
    name text,
    email text,
    phone text,
    membership membership_type,
    remaining_classes integer,
    membership_expiry timestamptz,
    extra_check_ins integer,
    is_new_member boolean,
    created_at timestamptz,
    updated_at timestamptz,
    daily_check_ins integer,
    last_check_in_date date
) AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM members
    WHERE 
        name ILIKE '%' || search_query || '%'
        OR email ILIKE '%' || search_query || '%'
        OR phone ILIKE '%' || search_query || '%';
END;
$$ LANGUAGE plpgsql;

COMMIT;
