BEGIN;

-- 重新创建 process_check_in 函数
CREATE OR REPLACE FUNCTION process_check_in()
RETURNS TRIGGER AS $$
DECLARE
  v_old_remaining_classes INTEGER;
  v_new_remaining_classes INTEGER;
  v_membership TEXT;
  v_is_new_member BOOLEAN;
  v_should_deduct BOOLEAN;
BEGIN
  -- 记录更新前的状态
  SELECT 
    remaining_classes, 
    membership,
    is_new_member 
  INTO 
    v_old_remaining_classes, 
    v_membership,
    v_is_new_member
  FROM members
  WHERE id = NEW.member_id;

  RAISE NOTICE '=== process_check_in 开始 ===';
  RAISE NOTICE '初始状态: member_id=%, membership=%, is_extra=%, old_remaining_classes=%, is_new_member=%',
    NEW.member_id, v_membership, NEW.is_extra, v_old_remaining_classes, v_is_new_member;

  -- 判断是否需要扣减课时
  v_should_deduct := v_membership IN ('single_class', 'two_classes', 'ten_classes') 
                     AND NOT NEW.is_extra;
  
  RAISE NOTICE '课时扣减判断: membership=%, is_extra=%, should_deduct=%',
    v_membership, NEW.is_extra, v_should_deduct;

  -- 更新会员信息
  UPDATE members
  SET 
    remaining_classes = CASE 
      WHEN v_should_deduct THEN remaining_classes - 1
      ELSE remaining_classes
    END,
    extra_check_ins = CASE 
      WHEN NEW.is_extra THEN extra_check_ins + 1
      ELSE extra_check_ins
    END,
    daily_check_ins = daily_check_ins + 1,
    last_check_in_date = NEW.check_in_date
  WHERE id = NEW.member_id
  RETURNING remaining_classes INTO v_new_remaining_classes;

  -- 验证更新结果
  RAISE NOTICE '更新结果: new_remaining_classes=%, changed=%, should_have_changed=%',
    v_new_remaining_classes, 
    (v_old_remaining_classes != v_new_remaining_classes),
    v_should_deduct;

  -- 验证新会员状态更新
  SELECT is_new_member INTO v_is_new_member
  FROM members
  WHERE id = NEW.member_id;

  RAISE NOTICE '新会员状态: before=%, after=%',
    v_is_new_member,
    (SELECT is_new_member FROM members WHERE id = NEW.member_id);

  RAISE NOTICE '=== process_check_in 结束 ===';

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ... 其他函数和触发器保持不变 ...

COMMIT; 