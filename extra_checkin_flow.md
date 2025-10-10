# 额外签到场景调用链和数据流分析

## 额外签到定义

根据系统规则，额外签到适用于以下情况：

1. **新会员首次签到**：系统自动创建会员档案，标记为新会员额外签到
2. **老会员无有效会员卡**：会员卡已过期或课时已用完
3. **老会员超出限制**：月卡超出每日上课次数限制

## 调用链分析

### 1. 签到验证流程

当会员进行签到时，系统会执行以下调用链：

```
签到请求 → check_in_validation_trigger → check_in_validation() → find_valid_card_trigger → find_valid_card_for_checkin() → validate_check_in() → update_member_status_trigger → update_member_status() → deduct_sessions_trigger → trigger_deduct_sessions() → deduct_membership_sessions()
```

### 2. 额外签到判断逻辑

额外签到的判断主要在以下几个环节：

#### 2.1 会员卡自动关联 (find_valid_card_for_checkin)

- 如果找不到有效会员卡，签到记录的`card_id`为NULL
- 日志记录："未找到有效会员卡"

#### 2.2 签到验证 (validate_check_in)

在`validate_check_in`函数中，系统会根据以下条件判断是否为额外签到：

- 如果`card_id`为NULL，则标记为额外签到
- 如果会员卡类型与课程类型不匹配，则标记为额外签到
- 如果会员卡已过期，则标记为额外签到
- 如果团课课时卡课时不足，则标记为额外签到
- 如果私教课时不足，则标记为额外签到
- 如果月卡超出每日限制，则标记为额外签到

#### 2.3 课时扣除 (trigger_deduct_sessions)

- 如果签到被标记为额外签到(`is_extra = true`)，则不扣除课时
- 日志记录："未扣除课时，原因：额外签到不扣除课时"

#### 2.4 会员状态更新 (update_member_status)

- 无论是否为额外签到，只要是新会员的首次签到，都会将会员状态从新会员更新为老会员
- 日志记录："会员状态已更新，old_status: new, new_status: old"

## 数据流分析

### 场景一：新会员首次签到

1. **输入**：会员姓名和邮箱
2. **处理流程**：
   - 系统创建新会员记录，标记为`is_new_member = true`
   - 创建签到记录，`card_id`为NULL
   - `find_valid_card_for_checkin`触发器尝试查找有效会员卡，但未找到
   - `update_member_status`触发器将会员状态更新为老会员(`is_new_member = false`)
   - `trigger_deduct_sessions`触发器检测到`card_id`为NULL，不扣除课时
3. **输出**：
   - 签到记录创建成功
   - 会员状态从新会员更新为老会员
   - 不扣除任何课时

### 场景二：老会员无有效会员卡

1. **输入**：会员姓名和邮箱，指定已过期或课时为0的会员卡
2. **处理流程**：
   - 创建签到记录，指定`card_id`
   - `validate_check_in`函数检测到会员卡已过期或课时为0，但未将签到标记为额外签到
   - `trigger_deduct_sessions`触发器尝试扣除课时，即使会员卡已过期或课时为0
   - `deduct_membership_sessions`函数扣除课时，导致课时变为负数
3. **输出**：
   - 签到记录创建成功
   - 会员卡课时被扣除，可能变为负数
   - **问题**：系统未正确识别无效会员卡的情况，未将签到标记为额外签到

### 场景三：老会员超出限制

1. **输入**：会员姓名和邮箱，使用月卡但已超出每日限制
2. **处理流程**：
   - 创建签到记录，指定`card_id`
   - `validate_check_in`函数检测到月卡超出每日限制，应将签到标记为额外签到
   - `trigger_deduct_sessions`触发器检测到`is_extra = true`，不扣除课时
3. **输出**：
   - 签到记录创建成功，标记为额外签到
   - 不扣除任何课时

## 问题与建议

1. **无效会员卡处理问题**：
   - 当使用已过期或课时为0的会员卡时，系统未将签到标记为额外签到
   - 系统仍然尝试扣除课时，导致课时变为负数

2. **改进建议**：
   - 修改`validate_check_in`函数，增强对无效会员卡的检测
   - 在`trigger_deduct_sessions`函数中增加对会员卡有效性的二次检查
   - 添加防止课时变为负数的保护机制

3. **日志记录增强**：
   - 在`validate_check_in`函数中添加更详细的日志，记录额外签到的具体原因
   - 在`deduct_membership_sessions`函数中添加对无效会员卡的警告日志

## 修复方案

### 1. 增强会员卡验证

修改`validate_check_in`函数，增强对无效会员卡的检测：

```sql
-- 会员卡有效性检查
IF v_card.valid_until IS NOT NULL AND v_card.valid_until < NEW.check_in_date THEN
  NEW.is_extra := true;
  INSERT INTO debug_logs (function_name, message, details)
  VALUES ('validate_check_in', '会员卡已过期', 
    jsonb_build_object('card_id', NEW.card_id, 'valid_until', v_card.valid_until));
END IF;

-- 课时检查
IF v_card.card_type = 'group' AND v_card.card_category = 'session' AND 
   (v_card.remaining_group_sessions IS NULL OR v_card.remaining_group_sessions <= 0) THEN
  NEW.is_extra := true;
  INSERT INTO debug_logs (function_name, message, details)
  VALUES ('validate_check_in', '团课课时不足', 
    jsonb_build_object('card_id', NEW.card_id, 'remaining_group_sessions', v_card.remaining_group_sessions));
END IF;
```

### 2. 防止课时变为负数

修改`deduct_membership_sessions`函数，添加防止课时变为负数的保护机制：

```sql
-- 团课课时扣除
IF NOT p_is_private AND (v_card.card_type = 'group' OR v_card.card_type = 'class') AND 
   (v_card.card_category = 'session' OR v_card.card_category = 'group') THEN
  -- 检查剩余课时
  IF v_card.remaining_group_sessions IS NULL OR v_card.remaining_group_sessions <= 0 THEN
    INSERT INTO debug_logs (function_name, message, details)
    VALUES ('deduct_membership_sessions', '团课课时不足，不扣除', 
      jsonb_build_object('card_id', p_card_id, 'remaining_group_sessions', v_card.remaining_group_sessions));
    RETURN;
  END IF;
  
  -- 扣除课时
  UPDATE membership_cards
  SET remaining_group_sessions = remaining_group_sessions - 1
  WHERE id = p_card_id;
  
  -- 记录日志
  INSERT INTO debug_logs (function_name, message, details)
  VALUES ('deduct_membership_sessions', '团课课时已扣除', 
    jsonb_build_object('card_id', p_card_id, 'remaining_group_sessions', v_card.remaining_group_sessions - 1));
END IF;