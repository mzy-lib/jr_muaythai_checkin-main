-- Fix member status for test members
UPDATE members 
SET is_new_member = false
WHERE email LIKE '%.test.mt@example.com'
  AND name IN ('张三', '李四', '王五', '赵六', '孙七', '周八');

-- Add comment
COMMENT ON TABLE members IS 'Updated 2024-03-20: Fixed new member status for test members';