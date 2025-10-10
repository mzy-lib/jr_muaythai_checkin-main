CREATE OR REPLACE FUNCTION public.check_duplicate_check_in(p_member_id uuid, p_date date, p_class_type text, p_time_slot text DEFAULT NULL::text)
 RETURNS jsonb
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
    RETURN jsonb_build_object(
      'has_duplicate', false,
      'message', '无效的课程类型: ' || p_class_type,
      'details', jsonb_build_object(
        'error', SQLERRM
      )
    );
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

    RETURN jsonb_build_object(
      'has_duplicate', true,
      'message', '今天已经在这个时段签到过了',
      'details', jsonb_build_object(
        'check_in_id', v_duplicate_check_in.id,
        'check_in_date', v_duplicate_check_in.check_in_date,
        'time_slot', v_duplicate_check_in.time_slot,
        'is_extra', v_duplicate_check_in.is_extra
      )
    );
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

  RETURN jsonb_build_object(
    'has_duplicate', false,
    'message', '未发现重复签到',
    'details', jsonb_build_object(
      'member_id', p_member_id,
      'date', p_date,
      'class_type', v_class_type,
      'time_slot', p_time_slot
    )
  );
END;
$function$; 