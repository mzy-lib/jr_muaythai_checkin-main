-- 向上迁移 (应用更改)
-- 添加性能优化索引

-- 优化会员签到查询
CREATE INDEX IF NOT EXISTS idx_check_ins_member_date_class 
ON check_ins(member_id, check_in_date, class_type);

-- 优化会员卡有效期查询
CREATE INDEX IF NOT EXISTS idx_membership_cards_valid_until 
ON membership_cards(valid_until);

-- 优化会员卡剩余课时查询
CREATE INDEX IF NOT EXISTS idx_membership_cards_remaining_sessions 
ON membership_cards(card_type, card_category, 
                   COALESCE(remaining_group_sessions, 0), 
                   COALESCE(remaining_private_sessions, 0));

-- 优化会员卡类型查询
CREATE INDEX IF NOT EXISTS idx_membership_cards_types
ON membership_cards(card_type, card_category, card_subtype);

-- 优化会员查询
CREATE INDEX IF NOT EXISTS idx_members_name_email
ON members(name, email);

-- 向下迁移 (回滚更改)
-- DROP INDEX IF EXISTS idx_members_name_email;
-- DROP INDEX IF EXISTS idx_membership_cards_types;
-- DROP INDEX IF EXISTS idx_membership_cards_remaining_sessions;
-- DROP INDEX IF EXISTS idx_membership_cards_valid_until;
-- DROP INDEX IF EXISTS idx_check_ins_member_date_class; 