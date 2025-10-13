-- 将handle_check_in函数设置为SECURITY DEFINER并授予公共执行权限
ALTER FUNCTION public.handle_check_in(uuid, text, text, uuid, text, date, text, uuid, boolean) SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.handle_check_in(uuid, text, text, uuid, text, date, text, uuid, boolean) TO public;
COMMENT ON FUNCTION public.handle_check_in IS '处理会员签到流程，包括会员验证、重复签到检查、会员卡验证、签到记录创建和会员信息更新';

