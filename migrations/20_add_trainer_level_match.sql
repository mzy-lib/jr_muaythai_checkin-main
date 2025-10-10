-- 向上迁移 (应用更改)
-- 添加教练等级匹配检查函数

-- 创建check_trainer_level_match函数
CREATE OR REPLACE FUNCTION check_trainer_level_match(
  p_card_trainer_type TEXT,
  p_trainer_type TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
  -- 如果会员卡要求高级教练，但实际教练是初级，返回false
  IF p_card_trainer_type = 'senior' AND p_trainer_type = 'jr' THEN
    RETURN FALSE;
  END IF;

  -- 其他情况都返回true
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- 向下迁移 (回滚更改)
-- 这里不提供回滚脚本，因为这是功能补充 