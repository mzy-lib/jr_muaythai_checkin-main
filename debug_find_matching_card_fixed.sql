-- 调试 find_matching_card 函数 - 修正版
-- 先检查表结构，然后查看为什么没有找到匹配的会员卡

-- 1. 检查 membership_cards 表结构
SELECT 
  '=== membership_cards 表结构 ===' as debug_section,
  column_name as field_name,
  data_type as field_type,
  CASE WHEN is_nullable = 'YES' THEN '可空' ELSE '非空' END as nullable_info
FROM information_schema.columns 
WHERE table_name = 'membership_cards' 
  AND table_schema = 'public'
ORDER BY ordinal_position

UNION ALL

-- 2. 检查该会员的所有会员卡数据
SELECT 
  '=== 会员卡数据 ===' as debug_section,
  mc.id::text as field_name,
  CONCAT(
    '类型:', COALESCE(mc.card_type::text, 'NULL'), 
    ' 激活:', COALESCE(mc.is_active::text, 'NULL'),
    ' 过期:', COALESCE(mc.expiry_date::text, 'NULL'),
    ' 教练:', COALESCE(mc.trainer_id::text, 'NULL')
  ) as field_type,
  '会员卡信息' as nullable_info
FROM membership_cards mc 
WHERE mc.member_id = '31f57d2d-eba7-431c-910a-6ab728ae571e'::uuid

UNION ALL

-- 3. 检查是否有剩余次数相关字段
SELECT 
  '=== 可能的剩余次数字段 ===' as debug_section,
  column_name as field_name,
  data_type as field_type,
  '检查字段' as nullable_info
FROM information_schema.columns 
WHERE table_name = 'membership_cards' 
  AND table_schema = 'public'
  AND (column_name ILIKE '%session%' OR column_name ILIKE '%remain%' OR column_name ILIKE '%count%' OR column_name ILIKE '%balance%')

ORDER BY debug_section, field_name;
