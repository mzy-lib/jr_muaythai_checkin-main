-- 插入测试数据
-- 1. 创建测试会员
INSERT INTO members (id, name, email, is_new_member)
VALUES 
  ('11111111-1111-1111-1111-111111111111', '测试会员A', 'member_a@test.com', false),  -- 有团课课时卡
  ('22222222-2222-2222-2222-222222222222', '测试会员B', 'member_b@test.com', false),  -- 有团课月卡
  ('33333333-3333-3333-3333-333333333333', '测试会员C', 'member_c@test.com', false),  -- 有私教卡
  ('44444444-4444-4444-4444-444444444444', '测试会员D', 'member_d@test.com', false),  -- 课时卡用完
  ('55555555-5555-5555-5555-555555555555', '测试会员E', 'member_e@test.com', false),  -- 无任何会员卡
  ('66666666-6666-6666-6666-666666666666', '测试会员F', 'member_f@test.com', false),  -- 私教卡用完
  ('77777777-7777-7777-7777-777777777777', '测试会员G', 'member_g@test.com', false);  -- 多卡会员：团课月卡+私教10次卡

-- 2. 插入会员卡数据
INSERT INTO membership_cards (id, member_id, card_type, card_category, card_subtype, remaining_group_sessions, remaining_private_sessions, valid_until)
VALUES
  -- 会员A的团课课时卡（10次卡，剩余5次）
  ('aaaaaaaa-1111-1111-1111-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'group', 'sessions', 'ten_classes', 5, NULL, CURRENT_DATE + INTERVAL '30 days'),
  
  -- 会员B的团课月卡（单次月卡）
  ('bbbbbbbb-2222-2222-2222-bbbbbbbbbbbb', '22222222-2222-2222-2222-222222222222', 'group', 'monthly', 'single', NULL, NULL, CURRENT_DATE + INTERVAL '30 days'),
  
  -- 会员C的私教卡（10次卡，剩余3次）
  ('cccccccc-3333-3333-3333-cccccccccccc', '33333333-3333-3333-3333-333333333333', 'private', 'sessions', 'ten_classes', NULL, 3, CURRENT_DATE + INTERVAL '30 days'),
  
  -- 会员D的团课课时卡（已用完）
  ('dddddddd-4444-4444-4444-dddddddddddd', '44444444-4444-4444-4444-444444444444', 'group', 'sessions', 'ten_classes', 0, NULL, CURRENT_DATE + INTERVAL '30 days'),
  
  -- 会员F的私教卡（已用完）
  ('ffffffff-6666-6666-6666-ffffffffffff', '66666666-6666-6666-6666-666666666666', 'private', 'sessions', 'ten_classes', NULL, 0, CURRENT_DATE + INTERVAL '30 days'),

  -- 会员G的团课月卡
  ('a7a7a7a7-7777-7777-7777-a7a7a7a7a7a7', '77777777-7777-7777-7777-777777777777', 'group', 'monthly', 'single', NULL, NULL, CURRENT_DATE + INTERVAL '30 days'),
  
  -- 会员G的私教10次卡（剩余8次）
  ('b7b7b7b7-7777-7777-7777-b7b7b7b7b7b7', '77777777-7777-7777-7777-777777777777', 'private', 'sessions', 'ten_classes', NULL, 8, CURRENT_DATE + INTERVAL '60 days');

-- 3. 清空签到记录
TRUNCATE TABLE check_ins CASCADE; 