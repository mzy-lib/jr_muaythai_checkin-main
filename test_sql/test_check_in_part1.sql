-- 测试数据准备
BEGIN;

-- 清理测试数据
DELETE FROM check_ins WHERE member_id IN (
  '11111111-1111-1111-1111-111111111111',
  '22222222-2222-2222-2222-222222222222',
  '33333333-3333-3333-3333-333333333333'
);

DELETE FROM membership_cards WHERE member_id IN (
  '11111111-1111-1111-1111-111111111111',
  '22222222-2222-2222-2222-222222222222',
  '33333333-3333-3333-3333-333333333333'
);

DELETE FROM members WHERE id IN (
  '11111111-1111-1111-1111-111111111111',
  '22222222-2222-2222-2222-222222222222',
  '33333333-3333-3333-3333-333333333333'
);

-- 创建测试会员
INSERT INTO members (id, name, email, is_new_member, extra_check_ins)
VALUES
  ('11111111-1111-1111-1111-111111111111', '测试新会员', 'new@test.com', false, 0),
  ('22222222-2222-2222-2222-222222222222', '测试老会员', 'old@test.com', false, 0),
  ('33333333-3333-3333-3333-333333333333', '测试额外签到会员', 'extra@test.com', false, 0);

-- 创建测试会员卡
-- 1. 有效的团课课时卡（10次卡）
INSERT INTO membership_cards (
  id, member_id, card_type, card_category, card_subtype,
  remaining_group_sessions, valid_until
)
VALUES (
  '11111111-2222-3333-4444-555555555555',
  '22222222-2222-2222-2222-222222222222',
  'group', 'session', '10_sessions',
  10, CURRENT_DATE + INTERVAL '3 months'
);

-- 2. 有效的团课月卡（单次月卡）
INSERT INTO membership_cards (
  id, member_id, card_type, card_category, card_subtype,
  valid_until
)
VALUES (
  '22222222-3333-4444-5555-666666666666',
  '22222222-2222-2222-2222-222222222222',
  'group', 'monthly', 'single_monthly',
  CURRENT_DATE + INTERVAL '30 days'
);

-- 3. 有效的私教课时卡（10次卡）
INSERT INTO membership_cards (
  id, member_id, card_type, card_category, card_subtype,
  remaining_private_sessions, trainer_type, valid_until
)
VALUES (
  '33333333-4444-5555-6666-777777777777',
  '22222222-2222-2222-2222-222222222222',
  'private', 'session', '10_sessions',
  10, 'senior', CURRENT_DATE + INTERVAL '1 month'
);

-- 4. 过期的团课课时卡
INSERT INTO membership_cards (
  id, member_id, card_type, card_category, card_subtype,
  remaining_group_sessions, valid_until
)
VALUES (
  '44444444-5555-6666-7777-888888888888',
  '33333333-3333-3333-3333-333333333333',
  'group', 'session', '10_sessions',
  5, CURRENT_DATE - INTERVAL '1 day'
);

-- 5. 课时用完的私教卡
INSERT INTO membership_cards (
  id, member_id, card_type, card_category, card_subtype,
  remaining_private_sessions, trainer_type, valid_until
)
VALUES (
  '55555555-6666-7777-8888-999999999999',
  '33333333-3333-3333-3333-333333333333',
  'private', 'session', '10_sessions',
  0, 'senior', CURRENT_DATE + INTERVAL '1 month'
);

-- 创建测试教练（如果不存在）
DO $$
DECLARE
  jr_exists INTEGER;
  da_exists INTEGER;
BEGIN
  -- 检查JR教练是否存在
  SELECT COUNT(*) INTO jr_exists FROM trainers WHERE name = 'JR';
  IF jr_exists = 0 THEN
    INSERT INTO trainers (id, name, type)
    VALUES ('99999999-8888-7777-6666-555555555555', 'JR', 'jr');
  END IF;
  
  -- 检查Da教练是否存在
  SELECT COUNT(*) INTO da_exists FROM trainers WHERE name = 'Da';
  IF da_exists = 0 THEN
    INSERT INTO trainers (id, name, type)
    VALUES ('88888888-7777-6666-5555-444444444444', 'Da', 'senior');
  END IF;
END $$;

-- 确保时间段格式正确
SELECT '测试用例1：新会员首次签到' AS test_case;
SELECT handle_check_in(
  '11111111-1111-1111-1111-111111111111',  -- 会员ID
  '测试新会员',                            -- 姓名
  'new@test.com',                         -- 邮箱
  NULL,                                   -- 会员卡ID（新会员没有卡）
  'morning',                              -- 课程类型
  CURRENT_DATE,                           -- 签到日期
  '09:00-10:30'                           -- 时间段（确保格式正确）
);

-- 测试用例2：老会员团课签到（课时卡）
SELECT '测试用例2：老会员团课签到（课时卡）' AS test_case;
SELECT handle_check_in(
  '22222222-2222-2222-2222-222222222222',  -- 会员ID
  '测试老会员',                            -- 姓名
  'old@test.com',                         -- 邮箱
  '11111111-2222-3333-4444-555555555555',  -- 团课课时卡ID
  'morning',                              -- 课程类型
  CURRENT_DATE,                           -- 签到日期
  '09:00-10:30'                           -- 时间段（确保格式正确）
);

-- 测试用例3：老会员团课签到（月卡）
SELECT '测试用例3：老会员团课签到（月卡）' AS test_case;
SELECT handle_check_in(
  '22222222-2222-2222-2222-222222222222',  -- 会员ID
  '测试老会员',                            -- 姓名
  'old@test.com',                         -- 邮箱
  '22222222-3333-4444-5555-666666666666',  -- 团课月卡ID
  'evening',                              -- 课程类型
  CURRENT_DATE,                           -- 签到日期
  '17:00-18:30'                           -- 时间段（确保格式正确）
);

COMMIT; 