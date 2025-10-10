-- 检查会员是否还存在
SELECT id, name, email 
FROM members 
WHERE name = '批量测试95';

-- 检查是否还有相关的签到记录
SELECT c.* 
FROM check_ins c
JOIN members m ON c.member_id = m.id
WHERE m.name = '批量测试95'; 