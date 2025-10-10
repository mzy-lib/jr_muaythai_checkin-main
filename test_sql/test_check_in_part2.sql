-- 测试数据准备 - 第二部分
BEGIN;

-- 测试用例4：老会员私教课签到（1v1）
SELECT '测试用例4：老会员私教课签到（1v1）' AS test_case;
SELECT handle_check_in(
  '22222222-2222-2222-2222-222222222222',  -- 会员ID
  '测试老会员',                            -- 姓名
  'old@test.com',                         -- 邮箱
  '33333333-4444-5555-6666-777777777777',  -- 私教课时卡ID
  'private',                              -- 课程类型
  CURRENT_DATE,                           -- 签到日期
  '10:30-12:00',                          -- 时间段
  '5e9a09da-01ed-4792-b661-d44562aa3393',  -- 教练ID (Da)
  false                                   -- 不是1v2课程
);

-- 测试用例5：老会员私教课签到（1v2）
SELECT '测试用例5：老会员私教课签到（1v2）' AS test_case;
SELECT handle_check_in(
  '22222222-2222-2222-2222-222222222222',  -- 会员ID
  '测试老会员',                            -- 姓名
  'old@test.com',                         -- 邮箱
  '33333333-4444-5555-6666-777777777777',  -- 私教课时卡ID
  'private',                              -- 课程类型
  (CURRENT_DATE + INTERVAL '1 day')::date, -- 签到日期（明天）
  '10:30-12:00',                          -- 时间段
  '5e9a09da-01ed-4792-b661-d44562aa3393',  -- 教练ID (Da)
  true                                    -- 是1v2课程
);

-- 测试用例6：额外签到（无卡）
SELECT '测试用例6：额外签到（无卡）' AS test_case;
SELECT handle_check_in(
  '33333333-3333-3333-3333-333333333333',  -- 会员ID
  '测试额外签到会员',                      -- 姓名
  'extra@test.com',                       -- 邮箱
  NULL,                                   -- 无卡
  'morning',                              -- 课程类型
  CURRENT_DATE,                           -- 签到日期
  '09:00-10:30',                          -- 时间段
  NULL                                    -- 无教练
);

-- 测试用例7：使用过期卡签到（应该成功并记录为额外签到）
SELECT '测试用例7：使用过期卡签到（应该成功并记录为额外签到）' AS test_case;
SELECT handle_check_in(
  '33333333-3333-3333-3333-333333333333',  -- 会员ID
  '测试额外签到会员',                      -- 姓名
  'extra@test.com',                       -- 邮箱
  '44444444-5555-6666-7777-888888888888',  -- 过期卡ID
  'evening',                              -- 课程类型（改为evening，与测试用例6不同）
  CURRENT_DATE,                           -- 签到日期
  '17:00-18:30'                           -- 时间段（改为晚课时间段）
);

-- 测试用例8：使用课时用完的卡签到（应该失败）
SELECT '测试用例8：使用课时用完的卡签到（应该失败）' AS test_case;
SELECT handle_check_in(
  '33333333-3333-3333-3333-333333333333',  -- 会员ID
  '测试额外签到会员',                      -- 姓名
  'extra@test.com',                       -- 邮箱
  '55555555-6666-7777-8888-999999999999',  -- 课时用完的卡ID
  'private',                              -- 课程类型
  CURRENT_DATE,                           -- 签到日期
  '10:30-12:00',                          -- 时间段
  '5e9a09da-01ed-4792-b661-d44562aa3393'   -- 教练ID (Da)
);

-- 测试用例9：重复签到（应该失败）
SELECT '测试用例9：重复签到（应该失败）' AS test_case;
-- 先执行一次签到
SELECT handle_check_in(
  '11111111-1111-1111-1111-111111111111',  -- 会员ID
  '测试新会员',                            -- 姓名
  'new@test.com',                         -- 邮箱
  NULL,                                   -- 会员卡ID（新会员没有卡）
  'evening',                              -- 课程类型
  CURRENT_DATE,                           -- 签到日期
  '17:00-18:30'                           -- 时间段
);

-- 然后尝试在同一时间段再次签到
SELECT handle_check_in(
  '11111111-1111-1111-1111-111111111111',  -- 会员ID
  '测试新会员',                            -- 姓名
  'new@test.com',                         -- 邮箱
  NULL,                                   -- 会员卡ID（新会员没有卡）
  'evening',                              -- 课程类型
  CURRENT_DATE,                           -- 签到日期
  '17:00-18:30'                           -- 时间段
);

-- 测试用例10：使用JR教练进行私教课签到
SELECT '测试用例10：使用JR教练进行私教课签到' AS test_case;
SELECT handle_check_in(
  '22222222-2222-2222-2222-222222222222',  -- 会员ID
  '测试老会员',                            -- 姓名
  'old@test.com',                         -- 邮箱
  '33333333-4444-5555-6666-777777777777',  -- 私教课时卡ID（senior类型）
  'private',                              -- 课程类型
  (CURRENT_DATE + INTERVAL '2 days')::date, -- 签到日期（后天）
  '10:30-12:00',                          -- 时间段
  '7a029490-917d-47d7-b222-b81f634d46ec'   -- 教练ID (JR)
);

-- 查询测试结果
SELECT '测试结果：会员签到记录' AS result_title;
SELECT m.name, c.check_in_date, c.class_type, c.time_slot, c.is_extra, 
       t.name AS trainer_name, c.is_1v2
FROM check_ins c
JOIN members m ON c.member_id = m.id
LEFT JOIN trainers t ON c.trainer_id = t.id
WHERE m.id IN (
  '11111111-1111-1111-1111-111111111111',
  '22222222-2222-2222-2222-222222222222',
  '33333333-3333-3333-3333-333333333333'
)
ORDER BY c.check_in_date, c.time_slot;

-- 查询会员卡状态
SELECT '测试结果：会员卡状态' AS result_title;
SELECT m.name, mc.card_type, mc.card_category, mc.card_subtype, 
       mc.remaining_group_sessions, mc.remaining_private_sessions, 
       mc.valid_until
FROM membership_cards mc
JOIN members m ON mc.member_id = m.id
WHERE m.id IN (
  '11111111-1111-1111-1111-111111111111',
  '22222222-2222-2222-2222-222222222222',
  '33333333-3333-3333-3333-333333333333'
)
ORDER BY m.name, mc.card_type;

-- 查询会员额外签到次数
SELECT '测试结果：会员额外签到次数' AS result_title;
SELECT name, extra_check_ins
FROM members
WHERE id IN (
  '11111111-1111-1111-1111-111111111111',
  '22222222-2222-2222-2222-222222222222',
  '33333333-3333-3333-3333-333333333333'
)
ORDER BY name;

COMMIT; 