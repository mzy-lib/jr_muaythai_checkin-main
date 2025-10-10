                                          pg_get_functiondef                                          
------------------------------------------------------------------------------------------------------
 CREATE OR REPLACE FUNCTION public.validate_member_name(p_name text, p_email text DEFAULT NULL::text)+
  RETURNS boolean                                                                                    +
  LANGUAGE plpgsql                                                                                   +
  SECURITY DEFINER                                                                                   +
  SET search_path TO 'public'                                                                        +
 AS $function$                                                                                       +
 BEGIN                                                                                               +
   -- Basic validation                                                                               +
   IF TRIM(p_name) = '' THEN                                                                         +
     RAISE EXCEPTION '姓名不能为空。Name cannot be empty.'                                           +
       USING HINT = 'empty_name';                                                                    +
   END IF;                                                                                           +
                                                                                                     +
   -- Check for invalid characters                                                                   +
   IF p_name !~ '^[a-zA-Z0-9\u4e00-\u9fa5@._\-\s]+$' THEN                                            +
     RAISE EXCEPTION '姓名包含无效字符。Name contains invalid characters.'                           +
       USING HINT = 'invalid_characters';                                                            +
   END IF;                                                                                           +
                                                                                                     +
   -- For new member registration, email is required                                                 +
   IF p_email IS NULL OR TRIM(p_email) = '' THEN                                                     +
     RAISE EXCEPTION '邮箱是必填字段。Email is required.'                                            +
       USING HINT = 'email_required';                                                                +
   END IF;                                                                                           +
                                                                                                     +
   RETURN true;                                                                                      +
 EXCEPTION                                                                                           +
   WHEN OTHERS THEN                                                                                  +
     RAISE;                                                                                          +
 END;                                                                                                +
 $function$                                                                                          +
 
(1 row)

