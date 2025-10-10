                                                 pg_get_functiondef                                                 
--------------------------------------------------------------------------------------------------------------------
 CREATE OR REPLACE FUNCTION public.validate_time_slot(p_time_slot text, p_check_in_date date, p_is_private boolean)+
  RETURNS boolean                                                                                                  +
  LANGUAGE plpgsql                                                                                                 +
  SECURITY DEFINER                                                                                                 +
  SET search_path TO 'public'                                                                                      +
 AS $function$                                                                                                     +
 BEGIN                                                                                                             +
   -- Basic format validation                                                                                      +
   IF p_time_slot !~ '^\d{2}:\d{2}-\d{2}:\d{2}$' THEN                                                              +
     RETURN false;                                                                                                 +
   END IF;                                                                                                         +
                                                                                                                   +
   -- For group classes                                                                                            +
   IF NOT p_is_private THEN                                                                                        +
     RETURN p_time_slot IN ('09:00-10:30', '17:00-18:30');                                                         +
   END IF;                                                                                                         +
                                                                                                                   +
   -- For private classes, trust the frontend validation                                                           +
   RETURN true;                                                                                                    +
 END;                                                                                                              +
 $function$                                                                                                        +
 
(1 row)

