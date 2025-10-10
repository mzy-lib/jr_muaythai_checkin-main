-- 向上迁移 (应用更改)
-- 修复validate_check_in函数中的类型不匹配问题

-- 修复validate_check_in函数
CREATE OR REPLACE FUNCTION validate_check_in() 
RETURNS trigger AS $$
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

  -- 只在开发环境记录详细日志
  IF current_setting('app.environment', true) = 'development' THEN
    INSERT INTO debug_logs (function_name, member_id, message, details)
    VALUES ('validate_check_in', NEW.member_id, 
      CASE WHEN NEW.is_extra THEN '额外签到' ELSE '正常签到' END, 
      jsonb_build_object(
        'check_in_date', NEW.check_in_date,
        'class_type', NEW.class_type,
        'is_extra', NEW.is_extra,
        'card_id', NEW.card_id
      )
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 向下迁移 (回滚更改)
-- 这里不提供回滚脚本，因为回滚会导致函数与表结构不匹配 