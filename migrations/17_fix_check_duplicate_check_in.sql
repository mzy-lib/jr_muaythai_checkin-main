-- 向上迁移 (应用更改)
-- 修复check_duplicate_check_in函数的返回值问题

-- 删除旧函数
DROP FUNCTION IF EXISTS check_duplicate_check_in(uuid, date, text, text);

-- 修改check_duplicate_check_in函数
CREATE OR REPLACE FUNCTION check_duplicate_check_in(
  p_member_id uuid,
  p_date date,
  p_class_type text,
  p_time_slot text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
AS $function$
DECLARE
  v_class_type class_type;
  v_is_private boolean;
  v_duplicate_check_in RECORD;
BEGIN
  -- 记录开始检查
  PERFORM log_debug(
    'check_duplicate_check_in',
    '开始检查重复签到',
    jsonb_build_object(
      'member_id', p_member_id,
      'date', p_date,
      'class_type', p_class_type,
      'time_slot', p_time_slot
    )
  );

  -- 转换课程类型
  BEGIN
    v_class_type := p_class_type::class_type;
    v_is_private := (v_class_type = 'private');
  EXCEPTION WHEN OTHERS THEN
    PERFORM log_debug(
      'check_duplicate_check_in',
      '无效的课程类型',
      jsonb_build_object(
        'class_type', p_class_type,
        'error', SQLERRM
      )
    );
    RETURN false;
  END;

  -- 检查重复签到
  SELECT *
  INTO v_duplicate_check_in
  FROM check_ins
  WHERE member_id = p_member_id
    AND check_in_date = p_date
    AND class_type = v_class_type
    AND (p_time_slot IS NULL OR time_slot = p_time_slot);

  -- 记录检查结果
  IF FOUND THEN
    PERFORM log_debug(
      'check_duplicate_check_in',
      '发现重复签到',
      jsonb_build_object(
        'member_id', p_member_id,
        'date', p_date,
        'class_type', v_class_type,
        'time_slot', COALESCE(p_time_slot, v_duplicate_check_in.time_slot),
        'duplicate_check_in', jsonb_build_object(
          'id', v_duplicate_check_in.id,
          'check_in_date', v_duplicate_check_in.check_in_date,
          'time_slot', v_duplicate_check_in.time_slot,
          'is_extra', v_duplicate_check_in.is_extra
        )
      )
    );

    RETURN true;
  END IF;

  -- 记录无重复签到
  PERFORM log_debug(
    'check_duplicate_check_in',
    '未发现重复签到',
    jsonb_build_object(
      'member_id', p_member_id,
      'date', p_date,
      'class_type', v_class_type,
      'time_slot', p_time_slot
    )
  );

  RETURN false;
END;
$function$;

-- 向下迁移 (回滚更改)
-- 这里不提供回滚脚本，因为这是bug修复 