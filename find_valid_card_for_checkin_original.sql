                                                     pg_get_functiondef                                                     
----------------------------------------------------------------------------------------------------------------------------
 CREATE OR REPLACE FUNCTION public.find_valid_card_for_checkin()                                                           +
  RETURNS trigger                                                                                                          +
  LANGUAGE plpgsql                                                                                                         +
 AS $function$                                                                                                             +
 DECLARE                                                                                                                   +
   v_card_id UUID;                                                                                                         +
   v_card_count INTEGER;                                                                                                   +
   v_card_records RECORD;                                                                                                  +
   v_member_name TEXT;                                                                                                     +
   v_class_type TEXT;                                                                                                      +
   v_sql TEXT;                                                                                                             +
   v_is_private BOOLEAN := NEW.is_private;                                                                                 +
   v_is_kids_group BOOLEAN := (NEW.class_type::TEXT IN ('kids_group', 'kids group'));                                      +
   v_is_normal_group BOOLEAN := (NEW.class_type::TEXT IN ('morning', 'evening') AND NOT NEW.is_private);                   +
 BEGIN                                                                                                                     +
   -- 跳过访客签到(member_id为NULL)或已指定会员卡                                                                          +
   IF NEW.member_id IS NULL OR NEW.card_id IS NOT NULL THEN                                                                +
     RETURN NEW;                                                                                                           +
   END IF;                                                                                                                 +
                                                                                                                           +
   -- 获取会员姓名用于日志                                                                                                 +
   SELECT name INTO v_member_name FROM members WHERE id = NEW.member_id;                                                   +
                                                                                                                           +
   -- 记录函数开始执行                                                                                                     +
   INSERT INTO debug_logs (function_name, message, details)                                                                +
   VALUES ('find_valid_card_for_checkin', '开始查找会员卡',                                                                +
     jsonb_build_object(                                                                                                   +
       'member_id', NEW.member_id,                                                                                         +
       'member_name', v_member_name,                                                                                       +
       'check_in_date', NEW.check_in_date,                                                                                 +
       'class_type', NEW.class_type,                                                                                       +
       'is_private', v_is_private,                                                                                         +
       'is_kids_group', v_is_kids_group,                                                                                   +
       'is_normal_group', v_is_normal_group,                                                                               +
       'time_slot', NEW.time_slot                                                                                          +
     )                                                                                                                     +
   );                                                                                                                      +
                                                                                                                           +
   -- 记录所有可能匹配的会员卡                                                                                             +
   INSERT INTO debug_logs (function_name, message, details)                                                                +
   VALUES ('find_valid_card_for_checkin', '会员所有卡',                                                                    +
     (SELECT jsonb_agg(jsonb_build_object(                                                                                 +
       'id', id,                                                                                                           +
       'card_type', card_type,                                                                                             +
       'card_category', card_category,                                                                                     +
       'valid_until', valid_until,                                                                                         +
       'remaining_group_sessions', remaining_group_sessions,                                                               +
       'remaining_private_sessions', remaining_private_sessions,                                                           +
       'remaining_kids_sessions', remaining_kids_sessions                                                                  +
     ))                                                                                                                    +
     FROM membership_cards                                                                                                 +
     WHERE member_id = NEW.member_id)                                                                                      +
   );                                                                                                                      +
                                                                                                                           +
   -- 根据课程类型查找会员卡                                                                                               +
   IF v_is_private THEN                                                                                                    +
     -- 查找私教课卡 - 兼容中英文卡类型                                                                                    +
     SELECT id INTO v_card_id                                                                                              +
     FROM membership_cards                                                                                                 +
     WHERE member_id = NEW.member_id                                                                                       +
       AND (card_type = '私教课' OR card_type = 'private')                                                                 +
       AND (remaining_private_sessions IS NULL OR remaining_private_sessions > 0)                                          +
       AND (valid_until IS NULL OR valid_until >= NEW.check_in_date)                                                       +
     LIMIT 1;                                                                                                              +
   ELSIF v_is_kids_group THEN                                                                                              +
     -- 查找儿童团课卡 - 保持原样，因为不常见其他命名                                                                      +
     SELECT id INTO v_card_id                                                                                              +
     FROM membership_cards                                                                                                 +
     WHERE member_id = NEW.member_id                                                                                       +
       AND card_type = '儿童团课'                                                                                          +
       AND (remaining_kids_sessions IS NULL OR remaining_kids_sessions > 0)                                                +
       AND (valid_until IS NULL OR valid_until >= NEW.check_in_date)                                                       +
     LIMIT 1;                                                                                                              +
   ELSIF v_is_normal_group THEN                                                                                            +
     -- 查找普通团课卡 - 兼容多种命名                                                                                      +
     SELECT id INTO v_card_id                                                                                              +
     FROM membership_cards                                                                                                 +
     WHERE member_id = NEW.member_id                                                                                       +
       AND (card_type = '团课' OR card_type = 'group' OR card_type = 'class')                                              +
       AND ((card_category IN ('课时卡', 'session') AND (remaining_group_sessions IS NULL OR remaining_group_sessions > 0))+
            OR card_category IN ('月卡', 'monthly'))                                                                       +
       AND (valid_until IS NULL OR valid_until >= NEW.check_in_date)                                                       +
     LIMIT 1;                                                                                                              +
   END IF;                                                                                                                 +
                                                                                                                           +
   -- 记录查找结果                                                                                                         +
   INSERT INTO debug_logs (function_name, message, details)                                                                +
   VALUES ('find_valid_card_for_checkin',                                                                                  +
     CASE WHEN v_card_id IS NOT NULL THEN '找到有效会员卡' ELSE '未找到有效会员卡' END,                                    +
     jsonb_build_object(                                                                                                   +
       'member_id', NEW.member_id,                                                                                         +
       'card_id', v_card_id,                                                                                               +
       'class_type', NEW.class_type,                                                                                       +
       'is_private', v_is_private,                                                                                         +
       'is_kids_group', v_is_kids_group,                                                                                   +
       'is_normal_group', v_is_normal_group                                                                                +
     )                                                                                                                     +
   );                                                                                                                      +
                                                                                                                           +
   -- 设置卡ID和额外签到标记                                                                                               +
   IF v_card_id IS NOT NULL THEN                                                                                           +
     NEW.card_id := v_card_id;                                                                                             +
     NEW.is_extra := false;                                                                                                +
   ELSE                                                                                                                    +
     NEW.is_extra := true;                                                                                                 +
   END IF;                                                                                                                 +
                                                                                                                           +
   RETURN NEW;                                                                                                             +
 END;                                                                                                                      +
 $function$                                                                                                                +
 
(1 行记录)

