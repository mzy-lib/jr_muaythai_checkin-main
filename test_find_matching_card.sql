-- 直接测试 find_matching_card 函数
-- 请将 member_id 和 trainer_id 替换为实际值

SELECT public.find_matching_card(
    (SELECT id FROM public.members WHERE name = 'test_m1'),  -- member_id
    'private',  -- class_type
    (SELECT id FROM public.trainers WHERE type = 'jr' LIMIT 1)  -- trainer_id (jr教练)
) as found_card_id;

-- 如果返回 NULL，说明函数工作正常
-- 如果返回卡片ID，说明函数有问题
