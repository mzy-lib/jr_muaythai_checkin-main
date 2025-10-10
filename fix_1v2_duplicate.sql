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
    RAISE NOTICE '发现重复1v2签到记录: 会员ID=%，日期=%，时间段=%，教练ID=%，记录数=%',
      v_duplicate.member_id, v_duplicate.check_in_date, v_duplicate.time_slot, 
      v_duplicate.trainer_id, v_duplicate.duplicate_count;
    
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
  -- 转换课程类型
  BEGIN
    v_class_type := p_class_type::class_type;
    v_is_private := (v_class_type = 'private');
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '无效的课程类型: %', p_class_type;
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

  RETURN FOUND;
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