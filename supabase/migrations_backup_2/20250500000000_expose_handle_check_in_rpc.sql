-- 确保handle_check_in函数可以作为RPC调用
-- 这个迁移文件将handle_check_in函数暴露为RPC接口，使前端可以直接调用

-- 确保函数有正确的安全设置
ALTER FUNCTION public.handle_check_in(
  p_member_id uuid, 
  p_name text, 
  p_email text, 
  p_class_type text, 
  p_check_in_date date, 
  p_card_id uuid, 
  p_trainer_id uuid, 
  p_is_1v2 boolean, 
  p_time_slot text
) SECURITY DEFINER;

-- 授予公共访问权限
GRANT EXECUTE ON FUNCTION public.handle_check_in(
  uuid, text, text, text, date, uuid, uuid, boolean, text
) TO public;

-- 添加函数注释
COMMENT ON FUNCTION public.handle_check_in IS '处理会员签到流程，包括会员验证、重复签到检查、会员卡验证、签到记录创建和会员信息更新。
参数:
- p_member_id: 会员ID
- p_name: 会员姓名
- p_email: 会员邮箱
- p_class_type: 课程类型（morning/evening/private）
- p_check_in_date: 签到日期
- p_card_id: 会员卡ID（可为NULL）
- p_trainer_id: 教练ID（私教课必填）
- p_is_1v2: 是否为1对2私教课
- p_time_slot: 时间段
返回: 包含签到结果的JSON对象'; 