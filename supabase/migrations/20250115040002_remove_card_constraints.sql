-- 移除会员卡表的约束条件
ALTER TABLE membership_cards
DROP CONSTRAINT IF EXISTS membership_cards_card_type_check,
DROP CONSTRAINT IF EXISTS membership_cards_card_category_check,
DROP CONSTRAINT IF EXISTS membership_cards_card_subtype_check;

-- 保留必要的外键约束
ALTER TABLE membership_cards
DROP CONSTRAINT IF EXISTS membership_cards_member_id_fkey,
ADD CONSTRAINT membership_cards_member_id_fkey 
    FOREIGN KEY (member_id) 
    REFERENCES members(id) 
    ON DELETE CASCADE; 