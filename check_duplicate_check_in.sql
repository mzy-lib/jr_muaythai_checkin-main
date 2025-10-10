                                                                pg_get_functiondef                                                                 
---------------------------------------------------------------------------------------------------------------------------------------------------
 CREATE OR REPLACE FUNCTION public.check_duplicate_check_in(p_member_id uuid, p_date date, p_class_type text, p_time_slot text DEFAULT NULL::text)+
  RETURNS boolean                                                                                                                                 +
  LANGUAGE plpgsql                                                                                                                                +
 AS $function$                                                                                                                                    +
 DECLARE                                                                                                                                          +
   v_class_type class_type;                                                                                                                       +
 BEGIN                                                                                                                                            +
   -- 转换class_type                                                                                                                              +
   BEGIN                                                                                                                                          +
     v_class_type := p_class_type::class_type;                                                                                                    +
   EXCEPTION WHEN OTHERS THEN                                                                                                                     +
     RAISE EXCEPTION '无效的课程类型: %', p_class_type;                                                                                           +
   END;                                                                                                                                           +
                                                                                                                                                  +
   RETURN EXISTS (                                                                                                                                +
     SELECT 1 FROM check_ins                                                                                                                      +
     WHERE member_id = p_member_id                                                                                                                +
     AND check_in_date = p_date                                                                                                                   +
     AND class_type = v_class_type                                                                                                                +
     AND (p_time_slot IS NULL OR time_slot = p_time_slot)                                                                                         +
   );                                                                                                                                             +
 END;                                                                                                                                             +
 $function$                                                                                                                                       +
 
(1 row)

