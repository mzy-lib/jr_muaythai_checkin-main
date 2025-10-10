-- 签到功能测试

-- 测试1: 新会员首次签到
DO $$
DECLARE
  test_date date := '2025-01-15'::date;
  v_member record;
  v_checkin record;
BEGIN
  RAISE NOTICE '=== 开始新会员首次签到测试 ===';
  
  -- 清理测试数据
  DELETE FROM check_ins WHERE id != '00000000-0000-0000-0000-000000000000';
  DELETE FROM members WHERE id != '00000000-0000-0000-0000-000000000000';
  
  -- 创建新会员
  WITH new_member AS (
    INSERT INTO members (
      name,
      email,
      is_new_member
    )
    VALUES (
      'test_member_' || current_date,
      'test.checkin.' || current_date || '@example.com',
      true
    )
    RETURNING *
  )
  SELECT * INTO v_member FROM new_member;

  -- 执行签到
  INSERT INTO check_ins (
    member_id,
    class_type,
    check_in_date
  )
  VALUES (
    v_member.id,
    'morning',
    test_date
  )
  RETURNING * INTO v_checkin;

  -- 验证签到结果
  ASSERT (
    SELECT is_extra 
    FROM check_ins 
    WHERE check_in_date = test_date
  ) = true, '新会员首次签到应为额外签到';

  RAISE NOTICE '=== 新会员首次签到测试完成 ===';
END $$;

-- 测试2: 月卡会员签到
DO $$
DECLARE
  test_date date := '2025-01-15'::date;
  v_member record;
  v_checkin1 record;
  v_checkin2 record;
BEGIN
  RAISE NOTICE '=== 开始月卡会员签到测试 ===';
  
  -- 清理测试数据
  DELETE FROM check_ins WHERE id != '00000000-0000-0000-0000-000000000000';
  DELETE FROM members WHERE id != '00000000-0000-0000-0000-000000000000';
  
  -- 创建月卡会员
  WITH new_member AS (
    INSERT INTO members (
      name,
      email,
      membership,
      membership_expiry,
      is_new_member
    )
    VALUES (
      'test_monthly_' || current_date,
      'test_monthly_' || current_date || '@example.com',
      'single_monthly',
      test_date + interval '1 month',
      false
    )
    RETURNING *
  )
  SELECT * INTO v_member FROM new_member;

  -- 第一次签到
  INSERT INTO check_ins (
    member_id,
    class_type,
    check_in_date
  )
  VALUES (
    v_member.id,
    'morning',
    test_date
  )
  RETURNING * INTO v_checkin1;

  -- 验证第一次签到
  ASSERT (
    SELECT is_extra 
    FROM check_ins 
    WHERE check_in_date = test_date
    AND class_type = 'morning'
  ) = false, '月卡会员第一次签到应为正常签到';

  -- 第二次签到
  INSERT INTO check_ins (
    member_id,
    class_type,
    check_in_date
  )
  VALUES (
    v_member.id,
    'evening',
    test_date
  )
  RETURNING * INTO v_checkin2;

  -- 验证第二次签到
  ASSERT (
    SELECT is_extra 
    FROM check_ins 
    WHERE check_in_date = test_date
    AND class_type = 'evening'
  ) = true, '月卡会员第二次签到应为额外签到';

  RAISE NOTICE '=== 月卡会员签到测试完成 ===';
END $$;

-- 测试3: 次卡会员签到
DO $$
DECLARE
  test_date date := '2025-01-15'::date;
  v_member record;
  v_checkin1 record;
  v_checkin2 record;
BEGIN
  RAISE NOTICE '=== 开始次卡会员签到测试 ===';
  
  -- 清理测试数据
  DELETE FROM check_ins WHERE id != '00000000-0000-0000-0000-000000000000';
  DELETE FROM members WHERE id != '00000000-0000-0000-0000-000000000000';
  
  -- 创建次卡会员
  WITH new_member AS (
    INSERT INTO members (
      name,
      email,
      membership,
      remaining_classes,
      is_new_member
    )
    VALUES (
      'test_single_' || current_date,
      'test_single_' || current_date || '@example.com',
      'single_class',
      1,
      false
    )
    RETURNING *
  )
  SELECT * INTO v_member FROM new_member;

  -- 第一次签到
  INSERT INTO check_ins (
    member_id,
    class_type,
    check_in_date
  )
  VALUES (
    v_member.id,
    'morning',
    test_date
  )
  RETURNING * INTO v_checkin1;

  -- 验证第一次签到
  ASSERT (
    SELECT is_extra 
    FROM check_ins 
    WHERE check_in_date = test_date
    AND class_type = 'morning'
  ) = false, '次卡会员第一次签到应为正常签到';

  -- 验证剩余次数
  ASSERT (
    SELECT remaining_classes
    FROM members
    WHERE id = v_member.id
  ) = 0, '次卡会员签到后剩余次数应为0';

  -- 第二次签到
  INSERT INTO check_ins (
    member_id,
    class_type,
    check_in_date
  )
  VALUES (
    v_member.id,
    'evening',
    test_date
  )
  RETURNING * INTO v_checkin2;

  -- 验证第二次签到
  ASSERT (
    SELECT is_extra 
    FROM check_ins 
    WHERE check_in_date = test_date
    AND class_type = 'evening'
  ) = true, '次卡会员第二次签到应为额外签到';

  RAISE NOTICE '=== 次卡会员签到测试完成 ===';
END $$; 