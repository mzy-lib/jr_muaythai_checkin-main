-- 修复会员卡与会员关联的验证问题
BEGIN;

-- 更新validate_check_in函数，确保会员卡与会员关联的验证
CREATE OR REPLACE FUNCTION validate_check_in()
RETURNS TRIGGER AS $$
DECLARE
  v_member RECORD;
  v_card RECORD;
  v_daily_check_ins integer;
  v_has_same_class_check_in boolean;
BEGIN
  -- 检查会员是否存在
  IF NOT check_member_exists(NEW.member_id) THEN
    RAISE EXCEPTION '会员不存在
Member not found';
  END IF;

  -- 检查是否重复签到
  IF check_duplicate_check_in(NEW.member_id, NEW.check_in_date, NEW.class_type::TEXT) THEN
    RAISE EXCEPTION '今天已经在这个时段签到过了
Already checked in for this class type today';
  END IF;

  -- 处理会员卡验证
  IF NEW.card_id IS NOT NULL THEN
    -- 只锁定会员卡记录，使用SKIP LOCKED避免等待
    SELECT * INTO v_card
    FROM membership_cards
    WHERE id = NEW.card_id
    FOR UPDATE SKIP LOCKED;

    IF NOT FOUND THEN
      RAISE EXCEPTION '会员卡不存在
Membership card not found';
    END IF;

    -- 严格验证会员卡与会员的关联
    IF v_card.member_id != NEW.member_id THEN
      RAISE EXCEPTION '会员卡不属于该会员
Membership card does not belong to this member';
    END IF;

    -- 使用CASE表达式简化条件判断
    NEW.is_extra := CASE
      -- 卡类型不匹配
      WHEN (v_card.card_type = 'group' AND NEW.class_type::TEXT = 'private') OR
           (v_card.card_type = 'private' AND NEW.class_type::TEXT != 'private') THEN true
      -- 卡已过期
      WHEN v_card.valid_until IS NOT NULL AND v_card.valid_until < NEW.check_in_date THEN true
      -- 团课课时卡课时不足
      WHEN v_card.card_type = 'group' AND v_card.card_category = 'session' AND
           (v_card.remaining_group_sessions IS NULL OR v_card.remaining_group_sessions <= 0) THEN true
      -- 私教课时不足
      WHEN v_card.card_type = 'private' AND
           (v_card.remaining_private_sessions IS NULL OR v_card.remaining_private_sessions <= 0) THEN true
      -- 月卡超出每日限制
      WHEN v_card.card_type = 'group' AND v_card.card_category = 'monthly' THEN
        CASE
          WHEN v_card.card_subtype = 'single_monthly' AND
               (SELECT COUNT(*) FROM check_ins
                WHERE member_id = NEW.member_id
                AND check_in_date = NEW.check_in_date
                AND id IS DISTINCT FROM NEW.id
                AND NOT is_extra) >= 1 THEN true
          WHEN v_card.card_subtype = 'double_monthly' AND
               (SELECT COUNT(*) FROM check_ins
                WHERE member_id = NEW.member_id
                AND check_in_date = NEW.check_in_date
                AND id IS DISTINCT FROM NEW.id
                AND NOT is_extra) >= 2 THEN true
          ELSE false
        END
      -- 其他情况为正常签到
      ELSE false
    END;
  ELSE
    -- 无会员卡时为额外签到
    NEW.is_extra := true;
  END IF;

  -- 记录详细日志
  INSERT INTO debug_logs (function_name, member_id, message, details)
  VALUES ('validate_check_in', NEW.member_id,
    '会员卡验证结果',
    jsonb_build_object(
      'card_id', NEW.card_id,
      'check_details', jsonb_build_object(
        'member_id', NEW.member_id,
        'class_type', NEW.class_type,
        'check_in_date', NEW.check_in_date
      ),
      'has_valid_card', NEW.card_id IS NOT NULL AND NOT NEW.is_extra,
      'card_belongs_to_member', CASE WHEN NEW.card_id IS NOT NULL THEN 
        (SELECT member_id FROM membership_cards WHERE id = NEW.card_id) = NEW.member_id
        ELSE NULL END
    )
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 创建一个专门验证会员卡与会员关联的触发器函数
CREATE OR REPLACE FUNCTION check_card_member_match()
RETURNS TRIGGER AS $$
DECLARE
  v_card_member_id UUID;
BEGIN
  -- 如果没有指定会员卡，则跳过验证
  IF NEW.card_id IS NULL THEN
    RETURN NEW;
  END IF;
  
  -- 获取会员卡所属的会员ID
  SELECT member_id INTO v_card_member_id
  FROM membership_cards
  WHERE id = NEW.card_id;
  
  -- 验证会员卡是否属于该会员
  IF v_card_member_id != NEW.member_id THEN
    RAISE EXCEPTION '会员卡不属于该会员
Membership card does not belong to this member';
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 创建触发器
DROP TRIGGER IF EXISTS check_card_member_match_trigger ON check_ins;
CREATE TRIGGER check_card_member_match_trigger
BEFORE INSERT OR UPDATE ON check_ins
FOR EACH ROW
EXECUTE FUNCTION check_card_member_match();

-- 修复现有的错误数据
DO $$
DECLARE
  v_invalid_check_in RECORD;
BEGIN
  -- 查找不匹配的签到记录
  FOR v_invalid_check_in IN
    SELECT c.id, c.member_id, c.card_id, m.member_id AS card_member_id
    FROM check_ins c
    JOIN membership_cards m ON c.card_id = m.id
    WHERE c.member_id != m.member_id
  LOOP
    -- 将这些记录标记为额外签到，并移除会员卡关联
    UPDATE check_ins
    SET is_extra = true, card_id = NULL
    WHERE id = v_invalid_check_in.id;
    
    -- 记录修复操作
    INSERT INTO debug_logs (function_name, message, details)
    VALUES ('fix_invalid_check_ins', '修复不匹配的签到记录',
      jsonb_build_object(
        'check_in_id', v_invalid_check_in.id,
        'member_id', v_invalid_check_in.member_id,
        'card_id', v_invalid_check_in.card_id,
        'card_member_id', v_invalid_check_in.card_member_id
      )
    );
  END LOOP;
END;
$$;

COMMIT; 