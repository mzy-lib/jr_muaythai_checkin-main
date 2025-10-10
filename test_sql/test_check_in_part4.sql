-- 测试数据准备 - 第四部分（测试已存在会员的额外签到和名字匹配问题）
BEGIN;

-- 清理测试数据
DELETE FROM check_ins WHERE member_id IN (
  '66666666-6666-6666-6666-777777777777',
  '77777777-7777-7777-7777-888888888888'
);

DELETE FROM membership_cards WHERE member_id IN (
  '66666666-6666-6666-6666-777777777777',
  '77777777-7777-7777-7777-888888888888'
);

DELETE FROM members WHERE id IN (
  '66666666-6666-6666-6666-777777777777',
  '77777777-7777-7777-7777-888888888888'
);

-- 创建测试会员
INSERT INTO members (id, name, email, is_new_member, extra_check_ins)
VALUES
  ('66666666-6666-6666-6666-777777777777', 'hongyiji', 'hongyiji@test.com', false, 0),
  ('77777777-7777-7777-7777-888888888888', '洪一吉', 'hong@test.com', false, 0);

-- 测试用例19：测试已存在会员的额外签到（通过ID）
SELECT '测试用例19：测试已存在会员的额外签到（通过ID）' AS test_case;
SELECT handle_check_in(
  '66666666-6666-6666-6666-777777777777',  -- 会员ID
  'hongyiji',                             -- 姓名
  'hongyiji@test.com',                    -- 邮箱
  NULL,                                   -- 无卡
  'morning',                              -- 课程类型
  CURRENT_DATE,                           -- 签到日期
  '09:00-10:30',                          -- 时间段
  NULL,                                   -- 无教练
  false                                   -- 非1v2
);

-- 测试用例20：测试已存在会员的额外签到（通过名字匹配）
SELECT '测试用例20：测试已存在会员的额外签到（通过名字匹配）' AS test_case;
SELECT handle_check_in(
  NULL,                                   -- 无会员ID
  'hongyiji',                             -- 姓名
  'new_email@test.com',                   -- 邮箱（不同的邮箱）
  NULL,                                   -- 无卡
  'evening',                              -- 课程类型
  CURRENT_DATE,                           -- 签到日期
  '17:00-18:30',                          -- 时间段
  NULL,                                   -- 无教练
  false                                   -- 非1v2
);

-- 测试用例21：测试中文名字匹配
SELECT '测试用例21：测试中文名字匹配' AS test_case;
SELECT handle_check_in(
  NULL,                                   -- 无会员ID
  '洪一吉',                               -- 中文姓名
  'new_email2@test.com',                  -- 邮箱（不同的邮箱）
  NULL,                                   -- 无卡
  'morning',                              -- 课程类型
  CURRENT_DATE,                           -- 签到日期
  '09:00-10:30',                          -- 时间段
  NULL,                                   -- 无教练
  false                                   -- 非1v2
);

-- 测试用例22：测试名字相似但不完全相同
SELECT '测试用例22：测试名字相似但不完全相同' AS test_case;
SELECT handle_check_in(
  NULL,                                   -- 无会员ID
  'hongyiji2',                            -- 相似但不同的名字
  'hongyiji@test.com',                    -- 相同的邮箱
  NULL,                                   -- 无卡
  'morning',                              -- 课程类型
  CURRENT_DATE,                           -- 签到日期
  '10:30-12:00',                          -- 时间段
  NULL,                                   -- 无教练
  false                                   -- 非1v2
);

-- 测试用例23：测试名字完全不同但邮箱相同
SELECT '测试用例23：测试名字完全不同但邮箱相同' AS test_case;
SELECT handle_check_in(
  NULL,                                   -- 无会员ID
  'completely_different',                 -- 完全不同的名字
  'hongyiji@test.com',                    -- 相同的邮箱
  NULL,                                   -- 无卡
  'evening',                              -- 课程类型
  CURRENT_DATE,                           -- 签到日期
  '17:00-18:30',                          -- 时间段
  NULL,                                   -- 无教练
  false                                   -- 非1v2
);

-- 测试用例24：测试名字和邮箱都不同（应该创建新会员）
SELECT '测试用例24：测试名字和邮箱都不同（应该创建新会员）' AS test_case;
SELECT handle_check_in(
  NULL,                                   -- 无会员ID
  'new_member_test',                      -- 新名字
  'new_member@test.com',                  -- 新邮箱
  NULL,                                   -- 无卡
  'morning',                              -- 课程类型
  CURRENT_DATE,                           -- 签到日期
  '09:00-10:30',                          -- 时间段
  NULL,                                   -- 无教练
  false                                   -- 非1v2
);

-- 查询测试结果
SELECT '测试结果：名字匹配测试的会员签到记录' AS result_title;
SELECT m.id, m.name, m.email, c.check_in_date, c.class_type, c.time_slot, c.is_extra
FROM check_ins c
JOIN members m ON c.member_id = m.id
WHERE m.name IN ('hongyiji', '洪一吉', 'hongyiji2', 'completely_different', 'new_member_test')
   OR m.id IN ('66666666-6666-6666-6666-777777777777', '77777777-7777-7777-7777-888888888888')
ORDER BY c.check_in_date, c.time_slot;

-- 查询会员额外签到次数
SELECT '测试结果：名字匹配测试的会员额外签到次数' AS result_title;
SELECT id, name, email, extra_check_ins
FROM members
WHERE name IN ('hongyiji', '洪一吉', 'hongyiji2', 'completely_different', 'new_member_test')
   OR id IN ('66666666-6666-6666-6666-777777777777', '77777777-7777-7777-7777-888888888888')
ORDER BY name;

-- 查询debug日志
SELECT '测试结果：名字匹配测试的debug日志' AS result_title;
SELECT * FROM debug_logs
WHERE message LIKE '%hongyiji%' OR message LIKE '%洪一吉%' OR message LIKE '%new_member%'
ORDER BY timestamp DESC
LIMIT 20;

COMMIT; 