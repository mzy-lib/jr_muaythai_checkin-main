-- 修复会员卡类型不一致问题的迁移脚本
-- 此脚本将标准化会员卡类型、类别和子类型，确保它们符合系统定义

-- 创建迁移日志表（如果不存在）
CREATE TABLE IF NOT EXISTS migration_logs (
    id SERIAL PRIMARY KEY,
    migration_name TEXT NOT NULL,
    description TEXT,
    executed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 第一步：将中文卡类型转换为英文
UPDATE membership_cards
SET card_type = 'group'
WHERE card_type = '团课';

UPDATE membership_cards
SET card_type = 'private'
WHERE card_type = '私教';

-- 第二步：标准化卡类别
UPDATE membership_cards
SET card_category = 'group'
WHERE card_type = 'class';

UPDATE membership_cards
SET card_category = 'session'
WHERE card_category = '课时卡';

UPDATE membership_cards
SET card_category = 'monthly'
WHERE card_category = '月卡';

-- 第三步：标准化卡子类型
UPDATE membership_cards
SET card_subtype = 'ten_classes'
WHERE card_subtype = '10次卡' OR card_subtype = '10_sessions';

UPDATE membership_cards
SET card_subtype = 'single_class'
WHERE card_subtype = '单次卡';

UPDATE membership_cards
SET card_subtype = 'single_monthly'
WHERE card_subtype = '单次月卡';

UPDATE membership_cards
SET card_subtype = 'double_monthly'
WHERE card_subtype = '双次月卡';

-- 第四步：确保所有卡都有正确的类别
UPDATE membership_cards
SET card_category = 'group'
WHERE card_type = 'class' AND (card_category IS NULL OR card_category = '');

UPDATE membership_cards
SET card_category = 'private'
WHERE card_type = 'private' AND (card_category IS NULL OR card_category = '');

UPDATE membership_cards
SET card_category = 'monthly'
WHERE card_type = 'monthly' AND (card_category IS NULL OR card_category = '');

-- 记录更改
INSERT INTO migration_logs (migration_name, description, executed_at)
VALUES ('20250401000000_fix_membership_card_inconsistencies', '标准化会员卡类型、类别和子类型', NOW());
