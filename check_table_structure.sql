-- 检查 membership_cards 表结构
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns 
WHERE table_name = 'membership_cards' 
  AND table_schema = 'public'
ORDER BY ordinal_position;
