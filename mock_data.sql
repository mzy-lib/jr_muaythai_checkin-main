-- 清空现有数据
TRUNCATE TABLE check_ins CASCADE;
TRUNCATE TABLE membership_cards CASCADE;
TRUNCATE TABLE members CASCADE;
TRUNCATE TABLE trainers CASCADE;

-- 创建教练数据
INSERT INTO trainers (id, name, type, notes) VALUES
('jr', 'JR', 'JR', 'JR教练'),
('da', 'Da', 'Senior', '高级教练'),
('ming', 'Ming', 'Senior', '高级教练'),
('big', 'Big', 'Senior', '高级教练'),
('bas', 'Bas', 'Senior', '高级教练'),
('sumay', 'Sumay', 'Senior', '高级教练'),
('first', 'First', 'Senior', '高级教练');

-- 创建会员数据
