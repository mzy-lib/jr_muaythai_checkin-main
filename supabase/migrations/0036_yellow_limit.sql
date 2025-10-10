-- Delete check-in records for test member
BEGIN;

-- Delete check-ins for the test member
DELETE FROM check_ins
WHERE member_id IN (
  SELECT id 
  FROM members 
  WHERE name = '新会员测试'
);

-- Delete the test member
DELETE FROM members
WHERE name = '新会员测试';

COMMIT;