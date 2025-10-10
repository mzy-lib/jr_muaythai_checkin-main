                                       pg_get_functiondef                                        
-------------------------------------------------------------------------------------------------
 CREATE OR REPLACE FUNCTION public.process_check_in()                                           +
  RETURNS trigger                                                                               +
  LANGUAGE plpgsql                                                                              +
 AS $function$                                                                                  +
 DECLARE                                                                                        +
   v_member RECORD;                                                                             +
 BEGIN                                                                                          +
   -- 更新会员信息                                                                              +
   UPDATE members                                                                               +
   SET                                                                                          +
     extra_check_ins = CASE WHEN NEW.is_extra THEN extra_check_ins + 1 ELSE extra_check_ins END,+
     last_check_in_date = NEW.check_in_date                                                     +
   WHERE id = NEW.member_id;                                                                    +
                                                                                                +
   -- 扣除课时                                                                                  +
   IF NEW.card_id IS NOT NULL AND NOT NEW.is_extra THEN                                         +
     PERFORM deduct_membership_sessions(NEW.card_id, NEW.class_type);                           +
   END IF;                                                                                      +
                                                                                                +
   -- 记录日志                                                                                  +
   IF current_setting('app.environment', true) = 'development' THEN                             +
     INSERT INTO debug_logs (function_name, message, member_id, details)                        +
     VALUES ('process_check_in', '处理完成', NEW.member_id,                                     +
       jsonb_build_object(                                                                      +
         'check_in_date', NEW.check_in_date,                                                    +
         'class_type', NEW.class_type,                                                          +
         'is_extra', NEW.is_extra,                                                              +
         'card_id', NEW.card_id                                                                 +
       )                                                                                        +
     );                                                                                         +
   END IF;                                                                                      +
                                                                                                +
   RETURN NULL;                                                                                 +
 END;                                                                                           +
 $function$                                                                                     +
 
(1 row)

