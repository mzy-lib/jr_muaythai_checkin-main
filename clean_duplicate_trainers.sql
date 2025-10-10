-- 清理重复的教练数据
-- 根据文档，我们应该只有7个教练：
-- JR类教练1名：JR
-- Senior类教练6名：Da, Ming, Big, Bas, Sumay, First

-- 开始事务
BEGIN;

-- 1. 删除不在文档中的教练（TestTrainer）
DELETE FROM trainers 
WHERE name = 'TestTrainer';

-- 2. 对于每个教练名称，保留最早创建的记录，删除其他重复记录

-- 删除重复的JR教练（保留最早创建的）
DELETE FROM trainers 
WHERE name = 'JR' 
AND id NOT IN (
    SELECT id FROM trainers 
    WHERE name = 'JR' 
    ORDER BY created_at ASC 
    LIMIT 1
);

-- 删除重复的Da教练（保留最早创建的）
DELETE FROM trainers 
WHERE name = 'Da' 
AND id NOT IN (
    SELECT id FROM trainers 
    WHERE name = 'Da' 
    ORDER BY created_at ASC 
    LIMIT 1
);

-- 删除重复的Ming教练（保留最早创建的）
DELETE FROM trainers 
WHERE name = 'Ming' 
AND id NOT IN (
    SELECT id FROM trainers 
    WHERE name = 'Ming' 
    ORDER BY created_at ASC 
    LIMIT 1
);

-- 3. 添加唯一性约束，防止将来出现重复
ALTER TABLE trainers ADD CONSTRAINT trainers_name_unique UNIQUE (name);

-- 提交事务
COMMIT;

-- 验证结果
SELECT id, name, type, notes, created_at FROM trainers ORDER BY type, name; 