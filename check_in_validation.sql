                                                 pg_get_functiondef                                                 
--------------------------------------------------------------------------------------------------------------------
 CREATE OR REPLACE FUNCTION public.check_in_validation()                                                           +
  RETURNS trigger                                                                                                  +
  LANGUAGE plpgsql                                                                                                 +
  SECURITY DEFINER                                                                                                 +
  SET search_path TO 'public'                                                                                      +
 AS $function$                                                                                                     +
 DECLARE                                                                                                           +
   v_duplicate_check_in RECORD;                                                                                     +
   v_time_slot_valid boolean;                                                                                       +
 BEGIN                                                                                                             +
   -- 验证时间段格式                                                                                             +
   IF NEW.time_slot IS NULL OR NEW.time_slot = '' THEN                                                                 +
     RAISE EXCEPTION '时间段不能为空
Time slot cannot be empty';                                                                                        +
   END IF;                                                                                                         +
                                                                                                                   +
   -- 验证时间段有效性                                                                                           +
   SELECT validate_time_slot(NEW.time_slot, NEW.check_in_date, NEW.is_private) INTO v_time_slot_valid;                  +
   IF NOT v_time_slot_valid THEN                                                                                   +
     RAISE EXCEPTION '无效的时间段: %
Invalid time slot: %', NEW.time_slot, NEW.time_slot;                                                                 +
   END IF;                                                                                                         +
                                                                                                                   +
   -- 设置课程类型                                                                                               +
   IF NEW.is_private THEN                                                                                          +
     NEW.class_type := 'private'::class_type;                                                                       +
   ELSE                                                                                                          +
     NEW.class_type := 'group'::class_type;                                                                         +
   END IF;                                                                                                         +
                                                                                                                   +
   -- 检查是否有重复签到（修改：考虑课程类型）                                                                   +
   -- 原来的代码会检查相同会员、日期、时间段和是否私教，现在我们修改为检查相同会员、日期、时间段和相同课程类型   +
   SELECT * INTO v_duplicate_check_in                                                                               +
   FROM check_ins                                                                                                  +
   WHERE member_id = NEW.member_id                                                                                   +
     AND check_in_date = NEW.check_in_date                                                                         +
     AND time_slot = NEW.time_slot                                                                                 +
     AND class_type = NEW.class_type                                                                                +
     AND id IS DISTINCT FROM NEW.id                                                                                +
   LIMIT 1;                                                                                                         +
                                                                                                                   +
   IF FOUND THEN                                                                                                   +
     IF NEW.is_private THEN                                                                                        +
       RAISE EXCEPTION '今天已经在这个时间段签到过私教课
Already checked in for private class at this time slot today';                                                  +
     ELSE                                                                                                          +
       RAISE EXCEPTION '今天已经在这个时间段签到过团课
Already checked in for group class at this time slot today';                                                  +
     END IF;                                                                                                       +
   END IF;                                                                                                         +
                                                                                                                   +
   RETURN NEW;                                                                                                     +
 END;                                                                                                              +
 $function$                                                                                                        +
 
(1 row)

