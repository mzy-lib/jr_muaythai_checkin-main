-- 调试 handle_check_in 函数的分步执行脚本
-- 在 Supabase 中执行此脚本来查看每一步的执行结果

WITH debug_steps AS (
  SELECT 
    '31f57d2d-eba7-431c-910a-6ab728ae571e'::uuid as p_member_id,
    'private'::text as p_class_type,
    CURRENT_DATE as p_check_in_date,
    'e1e7e142-2048-4fa4-98e9-bde6f9bb8e2d'::uuid as p_trainer_id,
    NULL::uuid as p_card_id,
    '09:00-10:00'::text as p_time_slot,
    false as p_is_1v2
),
step1_validation AS (
  SELECT 
    d.*,
    d.p_class_type::class_type as v_class_type_enum,
    (d.p_class_type::class_type = 'private'::class_type) as v_is_private,
    check_duplicate_check_in(d.p_member_id, d.p_check_in_date, d.p_class_type, d.p_time_slot) as has_duplicate
  FROM debug_steps d
),
step2_find_card AS (
  SELECT 
    s1.*,
    CASE 
      WHEN s1.v_is_private THEN 
        find_matching_card(s1.p_member_id, s1.p_class_type, s1.p_trainer_id)
      ELSE 
        s1.p_card_id
    END as v_matched_card_id
  FROM step1_validation s1
),
step3_validate_card AS (
  SELECT 
    s2.*,
    CASE 
      WHEN s2.v_matched_card_id IS NOT NULL THEN
        check_card_validity(s2.v_matched_card_id, s2.p_member_id, s2.p_check_in_date, s2.p_class_type, s2.p_trainer_id)
      ELSE
        NULL
    END as v_validity
  FROM step2_find_card s2
),
final_result AS (
  SELECT 
    s3.*,
    CASE 
      WHEN s3.v_matched_card_id IS NOT NULL AND (s3.v_validity->>'is_valid')::boolean THEN
        false  -- 正常签到
      ELSE
        true   -- 额外签到
    END as v_is_extra,
    CASE 
      WHEN s3.v_matched_card_id IS NULL THEN
        '未找到可用的会员卡'
      WHEN (s3.v_validity->>'is_valid')::boolean THEN
        '签到成功'
      ELSE
        s3.v_validity->>'reason'
    END as v_message,
    CASE 
      WHEN s3.v_matched_card_id IS NOT NULL AND NOT (s3.v_validity->>'is_valid')::boolean THEN
        NULL  -- 关键修复：验证失败时将卡ID设为NULL
      ELSE
        s3.v_matched_card_id
    END as final_card_id
  FROM step3_validate_card s3
)
SELECT 
  '=== 调试结果 ===' as debug_info,
  p_member_id as "输入_会员ID",
  p_class_type as "输入_课程类型", 
  p_trainer_id as "输入_教练ID",
  p_card_id as "输入_卡ID",
  '---' as separator1,
  v_class_type_enum as "步骤1_课程类型枚举",
  v_is_private as "步骤1_是否私教",
  has_duplicate as "步骤1_是否重复签到",
  '---' as separator2,
  v_matched_card_id as "步骤2_找到的卡ID",
  '---' as separator3,
  v_validity as "步骤3_卡验证结果",
  '---' as separator4,
  v_is_extra as "最终_是否额外签到",
  final_card_id as "最终_使用的卡ID",
  v_message as "最终_返回消息"
FROM final_result;
