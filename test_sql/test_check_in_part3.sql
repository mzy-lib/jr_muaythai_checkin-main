-- 测试数据准备 - 第三部分（特殊情况和边界条件）
BEGIN;

-- 清理测试数据
DELETE FROM check_ins WHERE member_id IN (
  '44444444-4444-4444-4444-444444444444',
  '55555555-5555-5555-5555-555555555555'
);

DELETE FROM membership_cards WHERE member_id IN (
  '44444444-4444-4444-4444-444444444444',
  '55555555-5555-5555-5555-555555555555'
);

DELETE FROM members WHERE id IN (
  '44444444-4444-4444-4444-444444444444',
  '55555555-5555-5555-5555-555555555555'
);

-- 创建测试会员
INSERT INTO members (id, name, email, is_new_member, extra_check_ins)
VALUES
  ('44444444-4444-4444-4444-444444444444', '测试边界会员1', 'edge1@test.com', false, 0),
  ('55555555-5555-5555-5555-555555555555', '测试边界会员2', 'edge2@test.com', false, 0);

-- 创建测试会员卡
-- 1. 即将过期的团课课时卡（今天过期）
INSERT INTO membership_cards (
  id, member_id, card_type, card_category, card_subtype,
  remaining_group_sessions, valid_until
)
VALUES (
  '66666666-6666-6666-6666-666666666666',
  '44444444-4444-4444-4444-444444444444',
  'group', 'session', '10_sessions',
  3, CURRENT_DATE
);

-- 2. 只剩1次课时的私教卡
INSERT INTO membership_cards (
  id, member_id, card_type, card_category, card_subtype,
  remaining_private_sessions, trainer_type, valid_until
)
VALUES (
  '77777777-7777-7777-7777-777777777777',
  '55555555-5555-5555-5555-555555555555',
  'private', 'session', '10_sessions',
  1, 'senior', CURRENT_DATE + INTERVAL '1 month'
);

-- 测试用例11：使用今天过期的卡签到
SELECT '测试用例11：使用今天过期的卡签到' AS test_case;
SELECT handle_check_in(
  '44444444-4444-4444-4444-444444444444',  -- 会员ID
  '测试边界会员1',                         -- 姓名
  'edge1@test.com',                       -- 邮箱
  '66666666-6666-6666-6666-666666666666',  -- 今天过期的卡ID
  'morning',                              -- 课程类型
  CURRENT_DATE,                           -- 签到日期
  '09:00-10:30'                           -- 时间段
);

-- 测试用例12：使用只剩1次课时的私教卡签到
SELECT '测试用例12：使用只剩1次课时的私教卡签到' AS test_case;
SELECT handle_check_in(
  '55555555-5555-5555-5555-555555555555',  -- 会员ID
  '测试边界会员2',                         -- 姓名
  'edge2@test.com',                       -- 邮箱
  '77777777-7777-7777-7777-777777777777',  -- 只剩1次课时的卡ID
  'private',                              -- 课程类型
  CURRENT_DATE,                           -- 签到日期
  '10:30-12:00',                          -- 时间段
  '5e9a09da-01ed-4792-b661-d44562aa3393'   -- 教练ID (Da)
);

-- 测试用例13：尝试再次使用已用完课时的私教卡签到（应该失败）
SELECT '测试用例13：尝试再次使用已用完课时的私教卡签到（应该失败）' AS test_case;
SELECT handle_check_in(
  '55555555-5555-5555-5555-555555555555',  -- 会员ID
  '测试边界会员2',                         -- 姓名
  'edge2@test.com',                       -- 邮箱
  '77777777-7777-7777-7777-777777777777',  -- 已用完课时的卡ID
  'private',                              -- 课程类型
  (CURRENT_DATE + INTERVAL '1 day')::date, -- 签到日期（明天）
  '10:30-12:00',                          -- 时间段
  '5e9a09da-01ed-4792-b661-d44562aa3393'   -- 教练ID (Da)
);

-- 测试用例14：测试无效的课程类型
SELECT '测试用例14：测试无效的课程类型' AS test_case;
SELECT handle_check_in(
  '44444444-4444-4444-4444-444444444444',  -- 会员ID
  '测试边界会员1',                         -- 姓名
  'edge1@test.com',                       -- 邮箱
  NULL,                                   -- 无卡
  'invalid_type',                         -- 无效的课程类型
  CURRENT_DATE,                           -- 签到日期
  '09:00-10:30'                           -- 时间段
);

-- 测试用例15：测试无效的时间段
SELECT '测试用例15：测试无效的时间段' AS test_case;
SELECT handle_check_in(
  '44444444-4444-4444-4444-444444444444',  -- 会员ID
  '测试边界会员1',                         -- 姓名
  'edge1@test.com',                       -- 邮箱
  NULL,                                   -- 无卡
  'morning',                              -- 课程类型
  CURRENT_DATE,                           -- 签到日期
  'invalid_time_slot'                     -- 无效的时间段
);

-- 测试用例16：测试私教课但不提供教练ID
SELECT '测试用例16：测试私教课但不提供教练ID' AS test_case;
SELECT handle_check_in(
  '44444444-4444-4444-4444-444444444444',  -- 会员ID
  '测试边界会员1',                         -- 姓名
  'edge1@test.com',                       -- 邮箱
  NULL,                                   -- 无卡
  'private',                              -- 私教课程类型
  CURRENT_DATE,                           -- 签到日期
  '10:30-12:00',                          -- 时间段
  NULL                                    -- 无教练ID
);

-- 测试用例17：测试非私教课但提供教练ID
SELECT '测试用例17：测试非私教课但提供教练ID' AS test_case;
SELECT handle_check_in(
  '44444444-4444-4444-4444-444444444444',  -- 会员ID
  '测试边界会员1',                         -- 姓名
  'edge1@test.com',                       -- 邮箱
  NULL,                                   -- 无卡
  'morning',                              -- 非私教课程类型
  CURRENT_DATE,                           -- 签到日期
  '09:00-10:30',                          -- 时间段
  '88888888-7777-6666-5555-444444444444'   -- 教练ID (Da)
);

-- 测试用例18：测试不存在的教练ID
SELECT '测试用例18：测试不存在的教练ID' AS test_case;
SELECT handle_check_in(
  '44444444-4444-4444-4444-444444444444',  -- 会员ID
  '测试边界会员1',                         -- 姓名
  'edge1@test.com',                       -- 邮箱
  NULL,                                   -- 无卡
  'private',                              -- 私教课程类型
  CURRENT_DATE,                           -- 签到日期
  '14:00-15:30',                          -- 时间段
  '12345678-1234-1234-1234-123456789012'   -- 不存在的教练ID
);

-- 查询测试结果
SELECT '测试结果：边界条件会员签到记录' AS result_title;
SELECT m.name, c.check_in_date, c.class_type, c.time_slot, c.is_extra, 
       t.name AS trainer_name, c.is_1v2
FROM check_ins c
JOIN members m ON c.member_id = m.id
LEFT JOIN trainers t ON c.trainer_id = t.id
WHERE m.id IN (
  '44444444-4444-4444-4444-444444444444',
  '55555555-5555-5555-5555-555555555555'
)
ORDER BY c.check_in_date, c.time_slot;

-- 查询会员卡状态
SELECT '测试结果：边界条件会员卡状态' AS result_title;
SELECT m.name, mc.card_type, mc.card_category, mc.card_subtype, 
       mc.remaining_group_sessions, mc.remaining_private_sessions, 
       mc.valid_until
FROM membership_cards mc
JOIN members m ON mc.member_id = m.id
WHERE m.id IN (
  '44444444-4444-4444-4444-444444444444',
  '55555555-5555-5555-5555-555555555555'
)
ORDER BY m.name, mc.card_type;

-- 查询debug日志
SELECT '测试结果：debug日志' AS result_title;
SELECT message, details
FROM debug_logs
WHERE function_name = 'handle_check_in'
ORDER BY timestamp DESC
LIMIT 10;

COMMIT; 