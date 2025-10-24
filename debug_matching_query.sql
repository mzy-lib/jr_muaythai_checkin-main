-- 调试查询：检查具体的匹配情况
-- 请将 'test_m1_member_id' 和 'test_trainer_id' 替换为实际的 UUID

-- 1. 查看该会员的所有私教卡
SELECT 
    id,
    card_type,
    trainer_type,
    remaining_private_sessions,
    valid_until,
    (valid_until IS NULL OR valid_until >= CURRENT_DATE) as is_valid
FROM public.membership_cards 
WHERE member_id = (SELECT id FROM public.members WHERE name = 'test_m1')
AND card_type = '私教课';

-- 2. 查看签到时使用的教练信息
SELECT 
    id,
    name,
    type,
    lower(trim(type)) as standardized_type
FROM public.trainers 
WHERE name LIKE '%JR%' OR type LIKE '%jr%' OR type LIKE '%JR%';

-- 3. 模拟 find_matching_card 函数的查找过程
WITH trainer_info AS (
    SELECT lower(trim(type)) as trainer_type
    FROM public.trainers 
    WHERE name LIKE '%JR%' OR type LIKE '%jr%' OR type LIKE '%JR%'
    LIMIT 1
)
SELECT 
    mc.id,
    mc.trainer_type,
    mc.remaining_private_sessions,
    mc.valid_until,
    ti.trainer_type as standardized_trainer_type,
    (lower(trim(mc.trainer_type)) = ti.trainer_type) as types_match
FROM public.membership_cards mc
CROSS JOIN trainer_info ti
WHERE 
    mc.member_id = (SELECT id FROM public.members WHERE name = 'test_m1')
    AND mc.card_type = '私教课'
    AND (mc.valid_until IS NULL OR mc.valid_until >= CURRENT_DATE)
    AND mc.remaining_private_sessions > 0;
