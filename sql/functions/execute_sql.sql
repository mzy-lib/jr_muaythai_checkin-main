-- 创建一个函数用于执行动态SQL查询
CREATE OR REPLACE FUNCTION execute_sql(sql_query text, params text[] DEFAULT NULL)
RETURNS SETOF json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result json;
BEGIN
  -- 记录执行的SQL到日志
  RAISE NOTICE 'Executing SQL: %', sql_query;
  RAISE NOTICE 'With params: %', params;
  
  -- 执行动态SQL并返回JSON结果
  FOR result IN EXECUTE sql_query USING VARIADIC params
  LOOP
    RETURN NEXT result;
  END LOOP;
  
  RETURN;
END;
$$; 