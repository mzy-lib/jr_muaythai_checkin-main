-- 查看 check_ins 表上的所有触发器
SELECT 
    tgname as trigger_name,
    pg_get_triggerdef(oid) as trigger_definition
FROM 
    pg_trigger 
WHERE 
    tgrelid = 'check_ins'::regclass; 