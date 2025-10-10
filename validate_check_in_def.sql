                                                      pg_get_functiondef                                                      
------------------------------------------------------------------------------------------------------------------------------
 CREATE OR REPLACE FUNCTION public.validate_check_in()                                                                       +
  RETURNS trigger                                                                                                            +
  LANGUAGE plpgsql                                                                                                           +
 AS $function$                                                                                                               +
 DECLARE                                                                                                                     +
   v_member RECORD;                                                                                                          +
   v_card RECORD;                                                                                                            +
   v_daily_check_ins integer;                                                                                                +
   v_has_same_class_check_in boolean;                                                                                        +
 BEGIN                                                                                                                       +
   -- 检查会员是否存在                                                                                                       +
   IF NOT check_member_exists(NEW.member_id) THEN                                                                            +
     RAISE EXCEPTION '会员不存在                                                                                             +
 Member not found';                                                                                                          +
   END IF;                                                                                                                   +
                                                                                                                             +
   -- 检查是否重复签到                                                                                                       +
   IF check_duplicate_check_in(NEW.member_id, NEW.check_in_date, NEW.class_type::TEXT) THEN                                  +
     RAISE EXCEPTION '今天已经签到过这个时段的课程。                                                                         +
 Already checked in for this time slot today.';                                                                              +
   END IF;                                                                                                                   +
                                                                                                                             +
   -- 处理会员卡验证                                                                                                         +
   IF NEW.card_id IS NOT NULL THEN                                                                                           +
     -- 只锁定会员卡记录，使用SKIP LOCKED避免等待                                                                            +
     SELECT * INTO v_card                                                                                                    +
     FROM membership_cards                                                                                                   +
     WHERE id = NEW.card_id                                                                                                  +
     FOR UPDATE SKIP LOCKED;                                                                                                 +
                                                                                                                             +
     IF NOT FOUND THEN                                                                                                       +
       RAISE EXCEPTION '会员卡不存在                                                                                         +
 Membership card not found';                                                                                                 +
     END IF;                                                                                                                 +
                                                                                                                             +
     -- 严格验证会员卡与会员的关联                                                                                           +
     IF v_card.member_id != NEW.member_id THEN                                                                               +
       RAISE EXCEPTION '会员卡不属于该会员                                                                                   +
 Membership card does not belong to this member';                                                                            +
     END IF;                                                                                                                 +
                                                                                                                             +
     -- 记录会员卡验证开始                                                                                                   +
     INSERT INTO debug_logs (function_name, message, details)                                                                +
     VALUES ('validate_check_in', '开始会员卡验证',                                                                          +
       jsonb_build_object(                                                                                                   +
         'card_id', NEW.card_id,                                                                                             +
         'member_id', NEW.member_id,                                                                                         +
         'check_in_date', NEW.check_in_date,                                                                                 +
         'valid_until', v_card.valid_until                                                                                   +
       )                                                                                                                     +
     );                                                                                                                      +
                                                                                                                             +
     -- 检查会员卡是否过期（修复：确保正确处理NULL值）                                                                       +
     IF v_card.valid_until IS NOT NULL AND v_card.valid_until < NEW.check_in_date THEN                                       +
       -- 记录会员卡过期                                                                                                     +
       INSERT INTO debug_logs (function_name, message, details)                                                              +
       VALUES ('validate_check_in', '会员卡已过期',                                                                          +
         jsonb_build_object(                                                                                                 +
           'card_id', NEW.card_id,                                                                                           +
           'valid_until', v_card.valid_until,                                                                                +
           'check_in_date', NEW.check_in_date                                                                                +
         )                                                                                                                   +
       );                                                                                                                    +
                                                                                                                             +
       -- 标记为额外签到                                                                                                     +
       NEW.is_extra := true;                                                                                                 +
                                                                                                                             +
       -- 记录额外签到原因                                                                                                   +
       INSERT INTO debug_logs (function_name, message, details)                                                              +
       VALUES ('validate_check_in', '额外签到原因',                                                                          +
         jsonb_build_object(                                                                                                 +
           'card_id', NEW.card_id,                                                                                           +
           'reason', '会员卡已过期',                                                                                         +
           'check_details', jsonb_build_object(                                                                              +
             'member_id', NEW.member_id,                                                                                     +
             'class_type', NEW.class_type,                                                                                   +
             'check_in_date', NEW.check_in_date,                                                                             +
             'card_type', v_card.card_type,                                                                                  +
             'card_category', v_card.card_category,                                                                          +
             'card_subtype', v_card.card_subtype,                                                                            +
             'valid_until', v_card.valid_until                                                                               +
           )                                                                                                                 +
         )                                                                                                                   +
       );                                                                                                                    +
     ELSE                                                                                                                    +
       -- 使用CASE表达式简化条件判断                                                                                         +
       NEW.is_extra := CASE                                                                                                  +
         -- 卡类型不匹配                                                                                                     +
         WHEN (v_card.card_type = 'group' AND NEW.class_type::TEXT = 'private') OR                                           +
              (v_card.card_type = 'private' AND NEW.class_type::TEXT != 'private') THEN true                                 +
         -- 团课课时卡课时不足                                                                                               +
         WHEN v_card.card_type = 'group' AND v_card.card_category = 'session' AND                                            +
              (v_card.remaining_group_sessions IS NULL OR v_card.remaining_group_sessions <= 0) THEN true                    +
         -- 私教课时不足                                                                                                     +
         WHEN v_card.card_type = 'private' AND                                                                               +
              (v_card.remaining_private_sessions IS NULL OR v_card.remaining_private_sessions <= 0) THEN true                +
         -- 月卡超出每日限制                                                                                                 +
         WHEN v_card.card_type = 'group' AND v_card.card_category = 'monthly' THEN                                           +
           CASE                                                                                                              +
             WHEN v_card.card_subtype = 'single_monthly' AND                                                                 +
                  (SELECT COUNT(*) FROM check_ins                                                                            +
                   WHERE member_id = NEW.member_id                                                                           +
                   AND check_in_date = NEW.check_in_date                                                                     +
                   AND id IS DISTINCT FROM NEW.id                                                                            +
                   AND NOT is_extra) >= 1 THEN true                                                                          +
             WHEN v_card.card_subtype = 'double_monthly' AND                                                                 +
                  (SELECT COUNT(*) FROM check_ins                                                                            +
                   WHERE member_id = NEW.member_id                                                                           +
                   AND check_in_date = NEW.check_in_date                                                                     +
                   AND id IS DISTINCT FROM NEW.id                                                                            +
                   AND NOT is_extra) >= 2 THEN true                                                                          +
             ELSE false                                                                                                      +
           END                                                                                                               +
         -- 其他情况为正常签到                                                                                               +
         ELSE false                                                                                                          +
       END;                                                                                                                  +
                                                                                                                             +
       -- 记录额外签到原因                                                                                                   +
       IF NEW.is_extra THEN                                                                                                  +
         INSERT INTO debug_logs (function_name, message, details)                                                            +
         VALUES ('validate_check_in', '额外签到原因',                                                                        +
           jsonb_build_object(                                                                                               +
             'card_id', NEW.card_id,                                                                                         +
             'reason', CASE                                                                                                  +
               WHEN (v_card.card_type = 'group' AND NEW.class_type::TEXT = 'private') OR                                     +
                    (v_card.card_type = 'private' AND NEW.class_type::TEXT != 'private') THEN '卡类型不匹配'                 +
               WHEN v_card.card_type = 'group' AND v_card.card_category = 'session' AND                                      +
                    (v_card.remaining_group_sessions IS NULL OR v_card.remaining_group_sessions <= 0) THEN '团课课时不足'    +
               WHEN v_card.card_type = 'private' AND                                                                         +
                    (v_card.remaining_private_sessions IS NULL OR v_card.remaining_private_sessions <= 0) THEN '私教课时不足'+
               WHEN v_card.card_type = 'group' AND v_card.card_category = 'monthly' THEN '月卡超出每日限制'                  +
               ELSE '未知原因'                                                                                               +
             END,                                                                                                            +
             'check_details', jsonb_build_object(                                                                            +
               'member_id', NEW.member_id,                                                                                   +
               'class_type', NEW.class_type,                                                                                 +
               'check_in_date', NEW.check_in_date,                                                                           +
               'card_type', v_card.card_type,                                                                                +
               'card_category', v_card.card_category,                                                                        +
               'card_subtype', v_card.card_subtype,                                                                          +
               'valid_until', v_card.valid_until,                                                                            +
               'remaining_group_sessions', v_card.remaining_group_sessions,                                                  +
               'remaining_private_sessions', v_card.remaining_private_sessions                                               +
             )                                                                                                               +
           )                                                                                                                 +
         );                                                                                                                  +
       END IF;                                                                                                               +
     END IF;                                                                                                                 +
   ELSE                                                                                                                      +
     -- 无会员卡时为额外签到                                                                                                 +
     NEW.is_extra := true;                                                                                                   +
                                                                                                                             +
     -- 记录额外签到原因                                                                                                     +
     INSERT INTO debug_logs (function_name, message, details)                                                                +
     VALUES ('validate_check_in', '额外签到原因',                                                                            +
       jsonb_build_object(                                                                                                   +
         'reason', '未指定会员卡',                                                                                           +
         'check_details', jsonb_build_object(                                                                                +
           'member_id', NEW.member_id,                                                                                       +
           'class_type', NEW.class_type,                                                                                     +
           'check_in_date', NEW.check_in_date                                                                                +
         )                                                                                                                   +
       )                                                                                                                     +
     );                                                                                                                      +
   END IF;                                                                                                                   +
                                                                                                                             +
   -- 记录详细日志                                                                                                           +
   INSERT INTO debug_logs (function_name, member_id, message, details)                                                       +
   VALUES ('validate_check_in', NEW.member_id,                                                                               +
     '会员卡验证结果',                                                                                                       +
     jsonb_build_object(                                                                                                     +
       'card_id', NEW.card_id,                                                                                               +
       'check_details', jsonb_build_object(                                                                                  +
         'member_id', NEW.member_id,                                                                                         +
         'class_type', NEW.class_type,                                                                                       +
         'check_in_date', NEW.check_in_date                                                                                  +
       ),                                                                                                                    +
       'has_valid_card', NEW.card_id IS NOT NULL AND NOT NEW.is_extra,                                                       +
       'card_belongs_to_member', CASE WHEN NEW.card_id IS NOT NULL THEN                                                      +
         (SELECT member_id FROM membership_cards WHERE id = NEW.card_id) = NEW.member_id                                     +
         ELSE NULL END                                                                                                       +
     )                                                                                                                       +
   );                                                                                                                        +
                                                                                                                             +
   RETURN NEW;                                                                                                               +
 END;                                                                                                                        +
 $function$                                                                                                                  +
 
(1 row)

