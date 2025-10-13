-- 添加唯一约束，防止同一会员有相同类型和子类型的多张卡
-- 记录迁移
INSERT INTO migration_logs (migration_name, description) 
VALUES ('20250401000004_add_unique_constraint_to_membership_cards', '为membership_cards表添加唯一约束，防止同一会员有相同类型和子类型的多张卡');

-- 添加唯一约束
ALTER TABLE membership_cards 
ADD CONSTRAINT unique_member_card_type 
UNIQUE (member_id, card_type, card_subtype);

-- 创建触发器函数，在插入或更新会员卡时检查是否有重复
CREATE OR REPLACE FUNCTION check_duplicate_membership_cards()
RETURNS TRIGGER AS $$
BEGIN
    -- 检查是否已存在相同会员、相同卡类型和子类型的卡
    IF EXISTS (
        SELECT 1 FROM membership_cards 
        WHERE member_id = NEW.member_id 
        AND card_type = NEW.card_type 
        AND card_subtype = NEW.card_subtype
        AND id != NEW.id
    ) THEN
        RAISE EXCEPTION '会员已有相同类型和子类型的卡，请更新现有卡或选择不同的卡类型';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 创建触发器
CREATE TRIGGER check_duplicate_cards_trigger
BEFORE INSERT OR UPDATE ON membership_cards
FOR EACH ROW
EXECUTE FUNCTION check_duplicate_membership_cards();

-- 添加注释
COMMENT ON CONSTRAINT unique_member_card_type ON membership_cards IS '确保同一会员不能有相同类型和子类型的多张卡';
COMMENT ON FUNCTION check_duplicate_membership_cards() IS '检查并防止插入或更新重复的会员卡'; 