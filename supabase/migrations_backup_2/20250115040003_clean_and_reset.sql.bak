-- 清理并重置数据库
TRUNCATE TABLE check_ins CASCADE;
TRUNCATE TABLE membership_cards CASCADE;
TRUNCATE TABLE members CASCADE;

-- 移除所有相关约束
ALTER TABLE membership_cards
DROP CONSTRAINT IF EXISTS membership_cards_sessions_check,
DROP CONSTRAINT IF EXISTS membership_cards_private_trainer_check,
DROP CONSTRAINT IF EXISTS membership_cards_monthly_check,
DROP CONSTRAINT IF EXISTS membership_cards_group_trainer_check,
DROP CONSTRAINT IF EXISTS membership_cards_remaining_sessions_check,
DROP CONSTRAINT IF EXISTS valid_card_combination; 