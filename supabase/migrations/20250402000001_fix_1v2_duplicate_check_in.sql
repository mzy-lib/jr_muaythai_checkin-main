-- 修复1v2私教课重复记录问题
BEGIN;

-- 创建新的函数来修复1v2私教课重复记录问题
CREATE OR REPLACE FUNCTION fix_1v2_duplicate_check_ins()
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_duplicate RECORD;
  v_count INTEGER := 0;
BEGIN
  -- 查找当前所有重复的1v2私教课签到记录
  FOR v_duplicate IN (
    SELECT 
      ci.member_id,
      ci.check_in_date,
      ci.time_slot,
      ci.trainer_id,
      COUNT(*) as duplicate_count,
      array_agg(ci.id) as check_in_ids
    FROM check_ins ci
    WHERE ci.is_1v2 = true
    AND ci.is_private = true
    GROUP BY ci.member_id, ci.check_in_date, ci.time_slot, ci.trainer_id
    HAVING COUNT(*) > 1
    ORDER BY ci.check_in_date DESC
  ) LOOP
    -- 保留第一条记录，删除其余的
    PERFORM log_debug(
      'fix_1v2_duplicate_check_ins',
      '发现重复1v2签到记录',
      jsonb_build_object(
        'member_id', v_duplicate.member_id,
        'check_in_date', v_duplicate.check_in_date,
        'time_slot', v_duplicate.time_slot,
        'trainer_id', v_duplicate.trainer_id,
        'duplicate_count', v_duplicate.duplicate_count,
        'check_in_ids', v_duplicate.check_in_ids
      )
    );
    
    -- 删除除第一条记录以外的所有记录
    DELETE FROM check_ins
    WHERE id = ANY(v_duplicate.check_in_ids[2:]);
    
    v_count := v_count + (v_duplicate.duplicate_count - 1);
  END LOOP;
  
  RAISE NOTICE '已修复 % 条重复的1v2私教课签到记录', v_count;
END;
$$;

-- 立即执行修复函数
SELECT fix_1v2_duplicate_check_ins();

-- 清理不再需要的函数
DROP FUNCTION fix_1v2_duplicate_check_ins();

-- 修改check_duplicate_check_in函数，确保考虑is_1v2参数
CREATE OR REPLACE FUNCTION check_duplicate_check_in(
  p_member_id uuid,
  p_date date,
  p_class_type text,
  p_time_slot text DEFAULT NULL,
  p_is_1v2 boolean DEFAULT false,
  p_trainer_id uuid DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
AS $$
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
      'time_slot', p_time_slot,
      'is_1v2', p_is_1v2,
      'trainer_id', p_trainer_id
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

  -- 检查重复签到（包含is_1v2和trainer_id）
  IF v_is_private THEN
    -- 对于私教课，检查会员、日期、时间段、教练和是否1v2
    SELECT *
    INTO v_duplicate_check_in
    FROM check_ins
    WHERE member_id = p_member_id
      AND check_in_date = p_date
      AND class_type = v_class_type
      AND (p_time_slot IS NULL OR time_slot = p_time_slot)
      AND (p_trainer_id IS NULL OR trainer_id = p_trainer_id)
      AND is_1v2 = p_is_1v2;
  ELSE
    -- 对于团课，只检查会员、日期、课程类型和时间段
    SELECT *
    INTO v_duplicate_check_in
    FROM check_ins
    WHERE member_id = p_member_id
      AND check_in_date = p_date
      AND class_type = v_class_type
      AND (p_time_slot IS NULL OR time_slot = p_time_slot);
  END IF;

  IF FOUND THEN
    PERFORM log_debug(
      'check_duplicate_check_in',
      '发现重复签到',
      jsonb_build_object(
        'member_id', p_member_id,
        'date', p_date,
        'class_type', v_class_type,
        'time_slot', v_duplicate_check_in.time_slot,
        'is_1v2', v_duplicate_check_in.is_1v2,
        'trainer_id', v_duplicate_check_in.trainer_id,
        'duplicate_id', v_duplicate_check_in.id
      )
    );
    RETURN true;
  END IF;

  PERFORM log_debug(
    'check_duplicate_check_in',
    '未发现重复签到',
    jsonb_build_object(
      'member_id', p_member_id,
      'date', p_date,
      'class_type', v_class_type,
      'time_slot', p_time_slot,
      'is_1v2', p_is_1v2,
      'trainer_id', p_trainer_id
    )
  );
  RETURN false;
END;
$$;

-- 修改handle_check_in函数，使用更新的check_duplicate_check_in函数
CREATE OR REPLACE FUNCTION handle_check_in(
  p_member_id uuid,
  p_name text,
  p_email text,
  p_card_id uuid,
  p_class_type text,
  p_check_in_date date,
  p_time_slot text,
  p_trainer_id uuid DEFAULT NULL,
  p_is_1v2 boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result jsonb;
  v_is_extra boolean;
  v_check_in_id uuid;
  v_class_type class_type;
  v_card_validity jsonb;
  v_is_new_member boolean := false;
  v_is_private boolean;
BEGIN
  -- 转换class_type
  BEGIN
    v_class_type := p_class_type::class_type;
    v_is_private := (v_class_type = 'private');
  EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', '无效的课程类型: ' || p_class_type,
      'error', SQLERRM
    );
  END;

  -- 验证时间段
  IF p_time_slot IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', '请选择有效的时间段',
      'error', 'time_slot_required'
    );
  END IF;

  -- 开始事务
  BEGIN
    -- 检查会员是否存在，不存在则创建
    IF NOT EXISTS (SELECT 1 FROM members WHERE id = p_member_id) THEN
      INSERT INTO members(id, name, email, is_new_member)
      VALUES (p_member_id, p_name, p_email, true);
      
      v_is_extra := true;
      v_is_new_member := true;
      
      PERFORM log_debug(
        'handle_check_in',
        '创建新会员',
        jsonb_build_object(
          'member_id', p_member_id,
          'name', p_name,
          'email', p_email
        )
      );
    END IF;

    -- 检查是否重复签到（考虑is_1v2和trainer_id）
    IF check_duplicate_check_in(p_member_id, p_check_in_date, p_class_type, p_time_slot, 
                               CASE WHEN v_is_private THEN p_is_1v2 ELSE false END,
                               CASE WHEN v_is_private THEN p_trainer_id ELSE NULL END) THEN
      RETURN jsonb_build_object(
        'success', false,
        'message', '今天已经在这个时段签到过了',
        'isDuplicate', true
      );
    END IF;

    -- 验证会员卡
    IF p_card_id IS NOT NULL THEN
      v_card_validity := check_card_validity(p_card_id, p_member_id, p_class_type, p_check_in_date);
      
      IF (v_card_validity->>'is_valid')::boolean THEN
        v_is_extra := false;
      ELSE
        v_is_extra := true;
        
        PERFORM log_debug(
          'handle_check_in',
          '会员卡验证失败',
          jsonb_build_object(
            'reason', v_card_validity->>'reason',
            'details', v_card_validity->'details'
          ),
          p_member_id
        );
      END IF;
    ELSE
      v_is_extra := true;
      
      PERFORM log_debug(
        'handle_check_in',
        '未指定会员卡',
        jsonb_build_object(
          'member_id', p_member_id,
          'class_type', p_class_type
        ),
        p_member_id
      );
    END IF;

    -- 插入签到记录
    INSERT INTO check_ins(
      member_id,
      card_id,
      class_type,
      check_in_date,
      trainer_id,
      is_1v2,
      is_extra,
      time_slot,
      is_private
    )
    VALUES (
      p_member_id,
      p_card_id,
      v_class_type,
      p_check_in_date,
      CASE WHEN v_is_private THEN p_trainer_id ELSE NULL END,
      CASE WHEN v_is_private THEN p_is_1v2 ELSE FALSE END,
      v_is_extra,
      p_time_slot,
      v_is_private
    )
    RETURNING id INTO v_check_in_id;

    -- 更新会员信息
    UPDATE members
    SET
      extra_check_ins = CASE WHEN v_is_extra THEN extra_check_ins + 1 ELSE extra_check_ins END,
      last_check_in_date = p_check_in_date
    WHERE id = p_member_id;

    -- 如果是正常签到（非额外签到），扣除课时
    IF NOT v_is_extra AND p_card_id IS NOT NULL THEN
      PERFORM deduct_membership_sessions(p_card_id, p_class_type, v_is_private, 
                                        CASE WHEN v_is_private THEN p_is_1v2 ELSE FALSE END);
    END IF;

    -- 构建返回结果
    v_result := jsonb_build_object(
      'success', true,
      'message', CASE
        WHEN v_is_new_member THEN '欢迎新会员！已记录签到'
        WHEN v_is_extra THEN CASE
          WHEN v_class_type IN ('morning', 'evening') THEN '您暂无有效的团课卡，已记录为额外签到'
          WHEN v_class_type = 'private' THEN '您暂无有效的私教卡，已记录为额外签到'
          ELSE '签到成功'
        END
        ELSE '签到成功'
      END,
      'isExtra', v_is_extra,
      'isNewMember', v_is_new_member,
      'checkInId', v_check_in_id
    );

    PERFORM log_debug(
      'handle_check_in',
      '签到成功',
      jsonb_build_object(
        'check_in_id', v_check_in_id,
        'is_extra', v_is_extra,
        'is_new_member', v_is_new_member,
        'class_type', p_class_type,
        'time_slot', p_time_slot,
        'is_1v2', CASE WHEN v_is_private THEN p_is_1v2 ELSE FALSE END
      ),
      p_member_id
    );

    RETURN v_result;
  EXCEPTION
    WHEN OTHERS THEN
      PERFORM log_debug(
        'handle_check_in',
        '签到失败',
        jsonb_build_object(
          'error', SQLERRM,
          'detail', SQLSTATE
        ),
        p_member_id
      );
      
      RAISE;
  END;
END;
$$;

-- 修改前端显示统计数据的SQL视图
CREATE OR REPLACE VIEW trainer_statistics AS
SELECT 
  t.id AS trainer_id,
  t.name AS trainer_name,
  t.type AS trainer_type,
  COUNT(DISTINCT ci.id) AS total_check_ins,
  COUNT(DISTINCT CASE WHEN ci.is_private AND NOT ci.is_1v2 THEN ci.id END) AS one_on_one_count,
  COUNT(DISTINCT CASE WHEN ci.is_private AND ci.is_1v2 THEN ci.id END) AS one_on_two_count,
  COUNT(DISTINCT CASE WHEN NOT ci.is_private THEN ci.id END) AS group_class_count,
  date_trunc('month', ci.check_in_date)::date AS month
FROM 
  trainers t
LEFT JOIN 
  check_ins ci ON t.id = ci.trainer_id
GROUP BY 
  t.id, t.name, t.type, date_trunc('month', ci.check_in_date)::date;

COMMIT; 