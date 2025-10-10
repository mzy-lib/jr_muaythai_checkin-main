-- 运行所有测试脚本
\echo '开始运行所有签到测试...'

-- 清空debug日志表
TRUNCATE debug_logs;

-- 运行第一部分测试：基本签到功能
\echo '\n=== 运行测试部分1：基本签到功能 ==='
\i test_sql/test_check_in_part1.sql

-- 运行第二部分测试：私教课签到和额外签到
\echo '\n=== 运行测试部分2：私教课签到和额外签到 ==='
\i test_sql/test_check_in_part2.sql

-- 运行第三部分测试：特殊情况和边界条件
\echo '\n=== 运行测试部分3：特殊情况和边界条件 ==='
\i test_sql/test_check_in_part3.sql

-- 运行第四部分测试：已存在会员的额外签到和名字匹配问题
\echo '\n=== 运行测试部分4：已存在会员的额外签到和名字匹配问题 ==='
\i test_sql/test_check_in_part4.sql

-- 显示所有测试结果摘要
\echo '\n=== 测试结果摘要 ==='

-- 显示所有成功的签到记录
\echo '\n成功的签到记录:'
SELECT m.name, c.check_in_date, c.class_type, c.time_slot, c.is_extra, 
       t.name AS trainer_name, c.is_1v2
FROM check_ins c
JOIN members m ON c.member_id = m.id
LEFT JOIN trainers t ON c.trainer_id = t.id
WHERE m.id IN (
  '11111111-1111-1111-1111-111111111111',
  '22222222-2222-2222-2222-222222222222',
  '33333333-3333-3333-3333-333333333333',
  '44444444-4444-4444-4444-444444444444',
  '55555555-5555-5555-5555-555555555555',
  '66666666-6666-6666-6666-777777777777',
  '77777777-7777-7777-7777-888888888888'
)
ORDER BY c.check_in_date, c.time_slot;

-- 显示所有会员的额外签到次数
\echo '\n会员额外签到次数:'
SELECT name, extra_check_ins
FROM members
WHERE id IN (
  '11111111-1111-1111-1111-111111111111',
  '22222222-2222-2222-2222-222222222222',
  '33333333-3333-3333-3333-333333333333',
  '44444444-4444-4444-4444-444444444444',
  '55555555-5555-5555-5555-555555555555',
  '66666666-6666-6666-6666-777777777777',
  '77777777-7777-7777-7777-888888888888'
)
ORDER BY name;

-- 显示所有会员卡状态
\echo '\n会员卡状态:'
SELECT m.name, mc.card_type, mc.card_category, mc.card_subtype, 
       mc.remaining_group_sessions, mc.remaining_private_sessions, 
       mc.valid_until
FROM membership_cards mc
JOIN members m ON mc.member_id = m.id
WHERE m.id IN (
  '11111111-1111-1111-1111-111111111111',
  '22222222-2222-2222-2222-222222222222',
  '33333333-3333-3333-3333-333333333333',
  '44444444-4444-4444-4444-444444444444',
  '55555555-5555-5555-5555-555555555555',
  '66666666-6666-6666-6666-777777777777',
  '77777777-7777-7777-7777-888888888888'
)
ORDER BY m.name, mc.card_type;

-- 显示最近的错误日志
\echo '\n最近的错误日志:'
SELECT timestamp, message
FROM debug_logs
WHERE message LIKE '%错误%' OR message LIKE '%失败%' OR message LIKE '%error%' OR message LIKE '%fail%'
ORDER BY timestamp DESC
LIMIT 20;

\echo '\n测试完成!' 