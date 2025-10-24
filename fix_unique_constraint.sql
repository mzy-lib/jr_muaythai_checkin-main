-- 修复 membership_cards 表的唯一约束
-- 删除现有的唯一约束并创建包含 trainer_type 的新约束

-- 1. 删除现有的唯一约束
ALTER TABLE membership_cards 
DROP CONSTRAINT IF EXISTS unique_member_card_type;

-- 2. 创建新的唯一约束，包含 trainer_type 字段
ALTER TABLE membership_cards 
ADD CONSTRAINT unique_member_card_type_trainer 
UNIQUE (member_id, card_type, card_subtype, trainer_type);

-- 验证约束是否创建成功
SELECT 
    conname as constraint_name,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint 
WHERE conrelid = 'membership_cards'::regclass 
AND contype = 'u';
