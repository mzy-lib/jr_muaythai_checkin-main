-- 标准化会员卡类型，使其符合readme.md中的定义
-- 此脚本将保留中文命名，但确保所有记录使用一致的类型

-- 确保迁移日志表存在
CREATE TABLE IF NOT EXISTS migration_logs (
    id SERIAL PRIMARY KEY,
    migration_name TEXT NOT NULL,
    description TEXT,
    executed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 创建临时表记录当前状态
CREATE TEMPORARY TABLE temp_membership_cards AS
SELECT id, card_type, card_category, card_subtype
FROM membership_cards;

-- 记录迁移前的状态
INSERT INTO migration_logs (migration_name, description)
VALUES ('20250401000002_standardize_membership_card_types', '标准化会员卡类型前的状态记录');

-- 第一步：标准化卡类型 (card_type)
-- 将所有团课相关的卡类型统一为"团课"
UPDATE membership_cards
SET card_type = '团课'
WHERE card_type IN ('class', 'group', 'monthly') OR card_type IS NULL;

-- 将所有私教相关的卡类型统一为"私教课"
UPDATE membership_cards
SET card_type = '私教课'
WHERE card_type IN ('private', '私教');

-- 第二步：标准化卡类别 (card_category)
-- 团课卡类别标准化
UPDATE membership_cards
SET card_category = '课时卡'
WHERE card_type = '团课' 
  AND (card_category IN ('session', 'sessions', 'group') 
       OR card_subtype IN ('single_class', 'two_classes', 'ten_classes', '单次卡', '两次卡', '10次卡')
       OR card_category IS NULL);

UPDATE membership_cards
SET card_category = '月卡'
WHERE card_type = '团课' 
  AND (card_category = 'monthly' 
       OR card_subtype IN ('single_monthly', 'double_monthly', '单次月卡', '双次月卡')
       OR (card_category IS NULL AND card_type = 'monthly'));

-- 私教卡不需要card_category，将其设为NULL
UPDATE membership_cards
SET card_category = NULL
WHERE card_type = '私教课';

-- 第三步：标准化卡子类型 (card_subtype)
-- 团课课时卡子类型标准化
UPDATE membership_cards
SET card_subtype = '单次卡'
WHERE card_type = '团课' 
  AND card_category = '课时卡'
  AND card_subtype IN ('single_class', 'standard');

UPDATE membership_cards
SET card_subtype = '两次卡'
WHERE card_type = '团课' 
  AND card_category = '课时卡'
  AND (card_subtype = 'two_classes' OR card_subtype = 'two_sessions');

UPDATE membership_cards
SET card_subtype = '10次卡'
WHERE card_type = '团课' 
  AND card_category = '课时卡'
  AND (card_subtype IN ('ten_classes', 'ten_sessions', '10_sessions') OR card_subtype = '10次卡');

-- 团课月卡子类型标准化
UPDATE membership_cards
SET card_subtype = '单次月卡'
WHERE card_type = '团课' 
  AND card_category = '月卡'
  AND (card_subtype = 'single_monthly' OR card_subtype = '单次月卡');

UPDATE membership_cards
SET card_subtype = '双次月卡'
WHERE card_type = '团课' 
  AND card_category = '月卡'
  AND (card_subtype = 'double_monthly' OR card_subtype = '双次月卡');

-- 私教卡子类型标准化
UPDATE membership_cards
SET card_subtype = '单次卡'
WHERE card_type = '私教课' 
  AND (card_subtype IN ('single_private', '单次卡'));

UPDATE membership_cards
SET card_subtype = '10次卡'
WHERE card_type = '私教课' 
  AND (card_subtype IN ('ten_private', '10_sessions', '10次卡'));

-- 记录迁移完成
INSERT INTO migration_logs (migration_name, description)
VALUES ('20250401000002_standardize_membership_card_types', '标准化会员卡类型完成');

-- 创建一个视图，用于前端显示会员卡信息
CREATE OR REPLACE VIEW membership_card_view AS
SELECT 
  id,
  member_id,
  card_type,
  card_category,
  card_subtype,
  trainer_type,
  remaining_group_sessions,
  remaining_private_sessions,
  valid_until,
  created_at,
  CASE 
    WHEN card_type = '团课' AND card_category = '课时卡' AND card_subtype = '单次卡' THEN 'single_class'
    WHEN card_type = '团课' AND card_category = '课时卡' AND card_subtype = '两次卡' THEN 'two_classes'
    WHEN card_type = '团课' AND card_category = '课时卡' AND card_subtype = '10次卡' THEN 'ten_classes'
    WHEN card_type = '团课' AND card_category = '月卡' AND card_subtype = '单次月卡' THEN 'single_monthly'
    WHEN card_type = '团课' AND card_category = '月卡' AND card_subtype = '双次月卡' THEN 'double_monthly'
    WHEN card_type = '私教课' AND card_subtype = '单次卡' THEN 'single_private'
    WHEN card_type = '私教课' AND card_subtype = '10次卡' THEN 'ten_private'
    ELSE card_subtype
  END AS card_subtype_code
FROM membership_cards;

COMMENT ON VIEW membership_card_view IS '会员卡视图，提供标准化的会员卡信息，包括代码映射'; 