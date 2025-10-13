-- 创建测试数据清理函数
CREATE OR REPLACE FUNCTION cleanup_test_data(p_name_pattern TEXT)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deleted_members INT;
  v_deleted_cards INT;
  v_deleted_check_ins INT;
BEGIN
  -- 删除符合模式的会员的签到记录
  DELETE FROM check_ins
  WHERE member_id IN (
    SELECT id FROM members
    WHERE name LIKE p_name_pattern
  );
  
  GET DIAGNOSTICS v_deleted_check_ins = ROW_COUNT;
  
  -- 删除符合模式的会员的会员卡
  DELETE FROM membership_cards
  WHERE member_id IN (
    SELECT id FROM members
    WHERE name LIKE p_name_pattern
  );
  
  GET DIAGNOSTICS v_deleted_cards = ROW_COUNT;
  
  -- 删除符合模式的会员
  DELETE FROM members
  WHERE name LIKE p_name_pattern;
  
  GET DIAGNOSTICS v_deleted_members = ROW_COUNT;
  
  -- 返回删除的记录数
  RETURN json_build_object(
    'deleted_members', v_deleted_members,
    'deleted_cards', v_deleted_cards,
    'deleted_check_ins', v_deleted_check_ins
  );
END;
$$;

-- 设置函数权限
GRANT EXECUTE ON FUNCTION cleanup_test_data(text) TO postgres, anon, authenticated, service_role; 