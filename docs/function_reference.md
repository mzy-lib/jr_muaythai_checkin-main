# JR泰拳馆签到系统函数参考

本文档详细说明了JR泰拳馆签到系统中的核心函数，包括其功能、参数、返回值和使用示例。

## 目录

1. [签到处理函数](#签到处理函数)
   - [handle_check_in](#handle_check_in)
2. [会员卡验证函数](#会员卡验证函数)
   - [check_card_validity](#check_card_validity)
3. [辅助函数](#辅助函数)
   - [check_member_exists](#check_member_exists)
   - [check_duplicate_check_in](#check_duplicate_check_in)
   - [check_monthly_card_daily_limit](#check_monthly_card_daily_limit)

---

## 签到处理函数

### handle_check_in

```sql
handle_check_in(
  p_member_id UUID,       -- 会员ID
  p_name TEXT,            -- 会员姓名
  p_email TEXT,           -- 会员邮箱
  p_card_id UUID,         -- 会员卡ID（可为NULL）
  p_class_type TEXT,      -- 课程类型（morning/evening/private）
  p_check_in_date DATE,   -- 签到日期
  p_trainer_id UUID DEFAULT NULL,  -- 教练ID（私教课必填）
  p_is_1v2 BOOLEAN DEFAULT FALSE   -- 是否为1对2私教课
) RETURNS JSONB
```

#### 功能说明

`handle_check_in`函数是签到系统的核心函数，负责处理会员签到的完整流程，包括：

1. 新会员自动建档
2. 老会员签到验证
3. 会员卡有效性检查
4. 签到记录创建
5. 会员信息更新

#### 参数说明

- `p_member_id`: 会员的唯一标识符（UUID格式）
- `p_name`: 会员姓名，用于显示和识别
- `p_email`: 会员邮箱，用于身份验证和通知
- `p_card_id`: 会员卡ID，如果会员没有卡或不使用卡签到，可为NULL
- `p_class_type`: 课程类型，可选值为：
  - `'morning'`：早课（9:00-10:30）
  - `'evening'`：晚课（17:00-18:30）
  - `'private'`：私教课
- `p_check_in_date`: 签到日期，通常为当天日期
- `p_trainer_id`: 教练ID，仅私教课需要指定
- `p_is_1v2`: 是否为1对2私教课，仅私教课适用

#### 返回值

返回一个JSON对象，包含以下字段：

- `success`: 布尔值，表示签到是否成功
- `message`: 文本消息，说明签到结果
- `isExtra`: 布尔值，表示是否为额外签到
- `checkInId`: 签到记录的唯一标识符（仅在签到成功时返回）
- `isDuplicate`: 布尔值，表示是否为重复签到（仅在重复签到时返回）
- `error`: 错误信息（仅在签到失败时返回）

#### 处理流程

1. 验证课程类型是否有效
2. 检查会员是否存在，不存在则创建新会员
3. 检查是否重复签到
4. 验证会员卡有效性（如果提供了会员卡ID）
5. 创建签到记录
6. 更新会员信息（额外签到次数和最后签到日期）
7. 返回签到结果

#### 使用示例

```sql
-- 新会员首次签到
SELECT handle_check_in(
  '11111111-1111-1111-1111-111111111111',  -- 会员ID
  '测试新会员',                            -- 姓名
  'new@test.com',                         -- 邮箱
  NULL,                                   -- 会员卡ID（新会员没有卡）
  'morning',                              -- 课程类型
  CURRENT_DATE,                           -- 签到日期
  NULL,                                   -- 教练ID（团课不需要）
  FALSE                                   -- 是否1对2（团课不适用）
);

-- 老会员使用团课课时卡签到
SELECT handle_check_in(
  '22222222-2222-2222-2222-222222222222',  -- 会员ID
  '测试老会员',                            -- 姓名
  'old@test.com',                         -- 邮箱
  '33333333-3333-3333-3333-333333333333',  -- 团课课时卡ID
  'evening',                              -- 课程类型
  CURRENT_DATE,                           -- 签到日期
  NULL,                                   -- 教练ID（团课不需要）
  FALSE                                   -- 是否1对2（团课不适用）
);

-- 老会员私教签到（1对1）
SELECT handle_check_in(
  '22222222-2222-2222-2222-222222222222',  -- 会员ID
  '测试老会员',                            -- 姓名
  'old@test.com',                         -- 邮箱
  '33333333-4444-5555-6666-777777777777',  -- 私教卡ID
  'private',                              -- 课程类型
  CURRENT_DATE,                           -- 签到日期
  '99999999-9999-9999-9999-999999999999',  -- 教练ID
  FALSE                                   -- 是否1对2（否，为1对1）
);
```

---

## 会员卡验证函数

### check_card_validity

```sql
check_card_validity(
  p_card_id UUID,        -- 会员卡ID
  p_member_id UUID,      -- 会员ID
  p_class_type TEXT,     -- 课程类型
  p_check_in_date DATE   -- 签到日期
) RETURNS BOOLEAN
```

#### 功能说明

`check_card_validity`函数用于检查会员卡是否有效，包括会员卡所有权验证、类型匹配检查、有效期检查和剩余课时检查。

#### 参数说明

- `p_card_id`: 会员卡的唯一标识符
- `p_member_id`: 会员的唯一标识符
- `p_class_type`: 课程类型，用于检查会员卡类型是否匹配
- `p_check_in_date`: 签到日期，用于检查会员卡是否在有效期内

#### 返回值

返回一个布尔值，表示会员卡是否有效：
- `TRUE`: 会员卡有效
- `FALSE`: 会员卡无效

#### 验证规则

1. 检查会员卡是否存在
2. 检查会员卡是否属于指定会员
3. 检查会员卡类型是否匹配课程类型
4. 检查会员卡是否在有效期内
5. 检查会员卡是否有足够的剩余课时

#### 使用示例

```sql
-- 检查团课课时卡是否有效
SELECT check_card_validity(
  '33333333-3333-3333-3333-333333333333',  -- 会员卡ID
  '22222222-2222-2222-2222-222222222222',  -- 会员ID
  'morning',                              -- 课程类型
  CURRENT_DATE                            -- 签到日期
);

-- 检查私教卡是否有效
SELECT check_card_validity(
  '33333333-4444-5555-6666-777777777777',  -- 会员卡ID
  '22222222-2222-2222-2222-222222222222',  -- 会员ID
  'private',                              -- 课程类型
  CURRENT_DATE                            -- 签到日期
);
```

---

## 辅助函数

### check_member_exists

```sql
check_member_exists(p_member_id UUID) RETURNS BOOLEAN
```

#### 功能说明

检查指定ID的会员是否存在于系统中。

#### 参数说明

- `p_member_id`: 会员的唯一标识符

#### 返回值

- `TRUE`: 会员存在
- `FALSE`: 会员不存在

#### 使用示例

```sql
-- 检查会员是否存在
SELECT check_member_exists('22222222-2222-2222-2222-222222222222');
```

### check_duplicate_check_in

```sql
check_duplicate_check_in(
  p_member_id UUID,
  p_check_in_date DATE,
  p_class_type TEXT
) RETURNS BOOLEAN
```

#### 功能说明

检查会员在指定日期和课程类型下是否已经签到过，防止重复签到。

#### 参数说明

- `p_member_id`: 会员的唯一标识符
- `p_check_in_date`: 签到日期
- `p_class_type`: 课程类型

#### 返回值

- `TRUE`: 已存在重复签到
- `FALSE`: 不存在重复签到

#### 使用示例

```sql
-- 检查是否重复签到
SELECT check_duplicate_check_in(
  '22222222-2222-2222-2222-222222222222',  -- 会员ID
  CURRENT_DATE,                           -- 签到日期
  'morning'                               -- 课程类型
);
```

### check_monthly_card_daily_limit

```sql
check_monthly_card_daily_limit(
  p_member_id UUID,
  p_card_id UUID,
  p_check_in_date DATE
) RETURNS BOOLEAN
```

#### 功能说明

检查会员的月卡在指定日期是否已达到每日签到次数限制。

#### 参数说明

- `p_member_id`: 会员的唯一标识符
- `p_card_id`: 会员卡的唯一标识符
- `p_check_in_date`: 签到日期

#### 返回值

- `TRUE`: 未达到每日签到次数限制
- `FALSE`: 已达到每日签到次数限制

#### 使用示例

```sql
-- 检查月卡每日签到次数限制
SELECT check_monthly_card_daily_limit(
  '22222222-2222-2222-2222-222222222222',  -- 会员ID
  '44444444-4444-4444-4444-444444444444',  -- 月卡ID
  CURRENT_DATE                            -- 签到日期
);
```

---

## 注意事项

1. 所有函数都应在事务中调用，以确保数据一致性
2. 在调用`handle_check_in`函数前，应先验证输入参数的有效性
3. 对于私教课签到，必须提供有效的教练ID
4. 会员卡ID可以为NULL，此时签到将被标记为额外签到

## 错误处理

所有函数都包含适当的错误处理机制，当发生错误时：

1. `handle_check_in`函数将返回包含错误信息的JSON对象
2. 其他函数将返回适当的布尔值或NULL
3. 在开发环境中，错误信息会被记录到`debug_logs`表中

--By Hongyi Ji hongyiji224@gmail.com 