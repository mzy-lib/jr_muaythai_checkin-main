BEGIN;

-- 1. 删除该会员的签到记录
DELETE FROM check_ins
WHERE member_id IN (
  SELECT id 
  FROM members 
  WHERE name = '批量测试95'
);

-- 2. 删除该会员
DELETE FROM members
WHERE name = '批量测试95';

COMMIT; 