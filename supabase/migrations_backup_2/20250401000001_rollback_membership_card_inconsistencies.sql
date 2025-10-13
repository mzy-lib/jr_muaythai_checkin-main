-- 回滚会员卡类型不一致修复的迁移脚本
-- 此脚本将恢复之前的会员卡类型、类别和子类型

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

-- 第一步：恢复中文卡类型
UPDATE membership_cards
SET card_type = '团课'
WHERE card_type = 'group' AND id IN (
    SELECT id FROM temp_membership_cards 
    WHERE card_category IN ('session', 'monthly') 
    AND card_subtype IN ('ten_classes', 'single_class', 'single_monthly', 'double_monthly')
);

UPDATE membership_cards
SET card_type = '私教'
WHERE card_type = 'private' AND id IN (
    SELECT id FROM temp_membership_cards 
    WHERE card_subtype IN ('ten_private')
);

-- 第二步：恢复原始卡类别
UPDATE membership_cards
SET card_category = '课时卡'
WHERE card_category = 'session' AND id IN (
    SELECT id FROM temp_membership_cards 
    WHERE card_type = 'group' 
    AND card_subtype IN ('ten_classes', 'single_class')
);

UPDATE membership_cards
SET card_category = '月卡'
WHERE card_category = 'monthly' AND id IN (
    SELECT id FROM temp_membership_cards 
    WHERE card_type = 'group' 
    AND card_subtype IN ('single_monthly', 'double_monthly')
);

-- 第三步：恢复原始卡子类型
UPDATE membership_cards
SET card_subtype = '10次卡'
WHERE card_subtype = 'ten_classes' AND id IN (
    SELECT id FROM temp_membership_cards 
    WHERE card_type = 'group' 
    AND card_category = 'session'
);

UPDATE membership_cards
SET card_subtype = '单次卡'
WHERE card_subtype = 'single_class' AND id IN (
    SELECT id FROM temp_membership_cards 
    WHERE card_type = 'group' 
    AND card_category = 'session'
);

UPDATE membership_cards
SET card_subtype = '单次月卡'
WHERE card_subtype = 'single_monthly' AND id IN (
    SELECT id FROM temp_membership_cards 
    WHERE card_type = 'group' 
    AND card_category = 'monthly'
);

UPDATE membership_cards
SET card_subtype = '双次月卡'
WHERE card_subtype = 'double_monthly' AND id IN (
    SELECT id FROM temp_membership_cards 
    WHERE card_type = 'group' 
    AND card_category = 'monthly'
);

-- 删除临时表
DROP TABLE temp_membership_cards;

-- 记录回滚操作
INSERT INTO migration_logs (migration_name, description, executed_at)
VALUES ('20250401000001_rollback_membership_card_inconsistencies', '回滚会员卡类型标准化', NOW()); 