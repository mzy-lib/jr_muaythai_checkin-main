-- 先删除刚创建的函数
DROP FUNCTION IF EXISTS public.register_new_member(text, text, text, boolean, boolean, text, uuid);

-- 创建或更新register_new_member函数，支持前端传入的参数集
CREATE OR REPLACE FUNCTION public.register_new_member(
  p_class_type text, 
  p_email text,
  p_is_1v2 boolean,
  p_is_private boolean,
  p_name text,
  p_time_slot text,
  p_trainer_id uuid DEFAULT NULL
) RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_member_id uuid;
  v_check_in_id uuid;
  v_existing_member RECORD;
  v_trainer_exists boolean;
  v_class_type class_type;
BEGIN
  -- 输入验证
  IF NOT validate_member_name(p_name) THEN
    RAISE EXCEPTION '无效的姓名格式。Invalid name format.'
      USING HINT = 'invalid_name';
  END IF;

  -- 设置课程类型
  IF p_class_type = 'private' THEN
    v_class_type := 'private'::class_type;
  ELSIF p_class_type = 'kids_group' THEN
    v_class_type := 'kids group'::class_type;
  ELSE
    -- 根据时间段确定是早班还是晚班
    IF p_time_slot LIKE '9:%' OR p_time_slot LIKE '09:%' OR p_time_slot LIKE '10:%' THEN
      v_class_type := 'morning'::class_type;
    ELSE
      v_class_type := 'evening'::class_type;
    END IF;
  END IF;

  -- 私教课验证
  IF p_is_private OR v_class_type = 'private' THEN
    -- 验证教练
    IF p_trainer_id IS NULL THEN
      RAISE EXCEPTION '私教课程必须选择教练。Trainer is required for private class.'
        USING HINT = 'trainer_required';
    END IF;

    -- 检查教练是否存在
    SELECT EXISTS (
      SELECT 1 FROM trainers WHERE id = p_trainer_id
    ) INTO v_trainer_exists;

    IF NOT v_trainer_exists THEN
      RAISE EXCEPTION '教练不存在。Trainer does not exist.'
        USING HINT = 'invalid_trainer';
    END IF;
  END IF;

  -- 检查是否已存在同名会员
  SELECT id, email, is_new_member 
  INTO v_existing_member
  FROM members
  WHERE LOWER(TRIM(name)) = LOWER(TRIM(p_name))
  FOR UPDATE SKIP LOCKED;

  IF FOUND THEN
    RAISE EXCEPTION '该姓名已被注册。This name is already registered.'
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

  -- 创建初始签到记录
  INSERT INTO check_ins (
    member_id,
    check_in_date,
    is_extra,
    is_private,
    trainer_id,
    time_slot,
    is_1v2,
    created_at,
    class_type
  ) VALUES (
    v_member_id,
    CURRENT_DATE,
    true,
    p_is_private,
    p_trainer_id,
    p_time_slot,
    p_is_1v2,
    NOW(),
    v_class_type
  ) RETURNING id INTO v_check_in_id;

  -- 返回成功响应
  RETURN json_build_object(
    'success', true,
    'member_id', v_member_id,
    'check_in_id', v_check_in_id
  );

EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION '该邮箱已被注册。This email is already registered.'
      USING HINT = 'email_exists';
  WHEN OTHERS THEN
    RAISE EXCEPTION '%', SQLERRM;
END;
$function$;

-- 添加函数注释
COMMENT ON FUNCTION public.register_new_member(text, text, boolean, boolean, text, text, uuid) IS 
'注册新会员并创建其首次签到记录。
支持参数:
- p_class_type: 课程类型 (private/kids_group/group)
- p_email: 会员邮箱
- p_is_1v2: 是否1v2课程
- p_is_private: 是否私教课
- p_name: 会员姓名  
- p_time_slot: 时间段
- p_trainer_id: 教练ID'; 