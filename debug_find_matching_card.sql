-- 调试 find_matching_card 函数
-- 查看为什么没有找到匹配的会员卡

WITH test_params AS (
  SELECT 
    '31f57d2d-eba7-431c-910a-6ab728ae571e'::uuid as member_id,
    'private'::text as class_type,
    'e1e7e142-2048-4fa4-98e9-bde6f9bb8e2d'::uuid as trainer_id
),
-- 1. 检查该会员的所有会员卡
member_cards AS (
  SELECT 
    mc.id as card_id,
    mc.card_type,
    mc.remaining_sessions,
    mc.expiry_date,
    mc.is_active,
    mc.trainer_id,
    mc.created_at
  FROM test_params tp
  JOIN membership_cards mc ON mc.member_id = tp.member_id
),
-- 2. 检查私教卡筛选条件
private_cards AS (
  SELECT 
    mc.*,
    CASE 
      WHEN mc.card_type = 'private'::card_type THEN '✓ 卡类型匹配'
      ELSE '✗ 卡类型不匹配: ' || mc.card_type::text
    END as type_check,
    CASE 
      WHEN mc.remaining_sessions > 0 THEN '✓ 剩余次数充足: ' || mc.remaining_sessions::text
      ELSE '✗ 剩余次数不足: ' || mc.remaining_sessions::text
    END as sessions_check,
    CASE 
      WHEN mc.expiry_date >= CURRENT_DATE THEN '✓ 未过期'
      ELSE '✗ 已过期: ' || mc.expiry_date::text
    END as expiry_check,
    CASE 
      WHEN mc.is_active THEN '✓ 卡片激活'
      ELSE '✗ 卡片未激活'
    END as active_check
  FROM member_cards mc
  CROSS JOIN test_params tp
),
-- 3. 检查教练匹配条件
trainer_match AS (
  SELECT 
    pc.*,
    CASE 
      WHEN pc.trainer_id IS NULL THEN '✓ 通用私教卡'
      WHEN pc.trainer_id = tp.trainer_id THEN '✓ 教练ID匹配'
      ELSE '✗ 教练ID不匹配: 卡片教练=' || pc.trainer_id::text || ', 请求教练=' || tp.trainer_id::text
    END as trainer_check,
    CASE 
      WHEN pc.card_type = 'private'::card_type 
           AND pc.remaining_sessions > 0 
           AND pc.expiry_date >= CURRENT_DATE 
           AND pc.is_active 
           AND (pc.trainer_id IS NULL OR pc.trainer_id = tp.trainer_id) 
      THEN '✓ 符合所有条件'
      ELSE '✗ 不符合条件'
    END as overall_check
  FROM private_cards pc
  CROSS JOIN test_params tp
),
-- 4. 模拟 find_matching_card 的排序逻辑
sorted_cards AS (
  SELECT 
    tm.*,
    ROW_NUMBER() OVER (
      ORDER BY 
        CASE WHEN tm.trainer_id IS NOT NULL THEN 0 ELSE 1 END,  -- 专属教练卡优先
        tm.expiry_date ASC,  -- 最早过期的优先
        tm.created_at ASC    -- 最早创建的优先
    ) as priority_rank
  FROM trainer_match tm
  WHERE tm.card_type = 'private'::card_type 
    AND tm.remaining_sessions > 0 
    AND tm.expiry_date >= CURRENT_DATE 
    AND tm.is_active 
    AND (tm.trainer_id IS NULL OR tm.trainer_id = (SELECT trainer_id FROM test_params))
)
-- 最终结果
SELECT 
  '=== find_matching_card 调试结果 ===' as debug_section,
  (SELECT member_id FROM test_params) as "查询的会员ID",
  (SELECT class_type FROM test_params) as "查询的课程类型",
  (SELECT trainer_id FROM test_params) as "查询的教练ID"

UNION ALL

SELECT 
  '=== 该会员的所有卡片 ===' as debug_section,
  card_id::text,
  card_type::text,
  CONCAT('剩余:', remaining_sessions::text, ' 过期:', expiry_date::text, ' 激活:', is_active::text, ' 教练:', COALESCE(trainer_id::text, 'NULL'))
FROM member_cards

UNION ALL

SELECT 
  '=== 卡片筛选详情 ===' as debug_section,
  card_id::text,
  CONCAT(type_check, ' | ', sessions_check, ' | ', expiry_check, ' | ', active_check, ' | ', trainer_check),
  overall_check
FROM trainer_match

UNION ALL

SELECT 
  '=== 符合条件的卡片(按优先级排序) ===' as debug_section,
  CONCAT('优先级:', priority_rank::text, ' 卡片ID:', card_id::text),
  CONCAT('教练:', COALESCE(trainer_id::text, 'NULL'), ' 过期:', expiry_date::text),
  '符合条件'
FROM sorted_cards
ORDER BY debug_section, card_id::text;
