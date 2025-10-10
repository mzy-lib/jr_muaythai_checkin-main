# 会员删除功能修复文档

## 问题描述

在会员管理页面尝试删除会员时，系统报错：

> 删除会员签到记录失败: update or delete on table "check_ins" violates foreign key constraint "check_in_logs_check_in_id_fkey" on table "check_in_logs"

这个错误表明存在外键约束问题。当系统尝试删除会员时，需要先删除该会员的签到记录（`check_ins`表），但这些签到记录被`check_in_logs`表引用，导致无法删除。

## 解决方案

我们通过以下步骤修复了这个问题：

1. **修改外键约束**：为`check_in_logs`表的外键约束添加级联删除（CASCADE）功能，使得删除签到记录时自动删除相关的日志记录。

2. **创建级联删除函数**：开发了`delete_member_cascade`函数，按照正确的顺序删除会员及其相关数据：
   - 先删除会员卡
   - 再删除签到记录（会自动级联删除签到日志）
   - 最后删除会员记录

3. **提供API函数**：创建了`delete_member`函数作为API接口，供前端调用，并添加了错误处理和日志记录功能。

## 实现细节

### 1. 修改外键约束

```sql
-- 先删除现有的外键约束
ALTER TABLE check_in_logs
DROP CONSTRAINT check_in_logs_check_in_id_fkey;

-- 重新创建外键约束，添加级联删除
ALTER TABLE check_in_logs
ADD CONSTRAINT check_in_logs_check_in_id_fkey
FOREIGN KEY (check_in_id)
REFERENCES check_ins(id)
ON DELETE CASCADE;
```

### 2. 级联删除函数

```sql
CREATE OR REPLACE FUNCTION delete_member_cascade(p_member_id UUID)
RETURNS VOID AS $$
BEGIN
    -- 记录开始删除会员
    INSERT INTO debug_logs (function_name, message, details)
    VALUES ('delete_member_cascade', '开始删除会员及相关数据',
        jsonb_build_object(
            'member_id', p_member_id
        )
    );
    
    -- 删除会员的会员卡
    DELETE FROM membership_cards
    WHERE member_id = p_member_id;
    
    -- 删除会员的签到记录（会自动级联删除check_in_logs中的记录）
    DELETE FROM check_ins
    WHERE member_id = p_member_id;
    
    -- 最后删除会员记录
    DELETE FROM members
    WHERE id = p_member_id;
    
    -- 记录删除完成
    INSERT INTO debug_logs (function_name, message, details)
    VALUES ('delete_member_cascade', '会员及相关数据删除完成',
        jsonb_build_object(
            'member_id', p_member_id
        )
    );
EXCEPTION
    WHEN OTHERS THEN
        -- 记录删除失败
        INSERT INTO debug_logs (function_name, message, details)
        VALUES ('delete_member_cascade', '删除会员失败',
            jsonb_build_object(
                'member_id', p_member_id,
                'error', SQLERRM,
                'error_detail', SQLSTATE
            )
        );
        RAISE;
END;
$$ LANGUAGE plpgsql;
```

### 3. API函数

```sql
CREATE OR REPLACE FUNCTION public.delete_member(p_member_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    -- 调用级联删除函数
    PERFORM delete_member_cascade(p_member_id);
    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

## 使用方法

### 前端调用

在前端代码中，可以通过以下方式调用删除会员API：

```javascript
// 使用Supabase客户端调用
const { data, error } = await supabase
  .rpc('delete_member', { p_member_id: memberId });

if (error) {
  console.error('删除会员失败:', error);
  // 显示错误消息
  showErrorMessage('删除会员失败，请稍后重试');
} else if (data) {
  // 删除成功
  showSuccessMessage('会员已成功删除');
  // 刷新会员列表
  refreshMemberList();
}
```

### 数据库直接调用

如果需要在数据库中直接删除会员，可以执行：

```sql
SELECT delete_member('会员ID');
```

## 测试结果

我们创建了测试会员并添加了签到记录和签到日志，然后测试了删除功能。结果显示：

1. 会员记录被成功删除
2. 会员的签到记录被成功删除
3. 签到日志被自动级联删除
4. 系统记录了完整的删除过程日志

## 注意事项

1. **数据备份**：在大规模删除会员前，建议先备份数据库。

2. **权限控制**：确保只有管理员用户有权限删除会员。

3. **前端确认**：在前端实现中，应添加删除确认对话框，避免误操作。

4. **日志查询**：如果需要查看删除操作的日志，可以查询`debug_logs`表：
   ```sql
   SELECT * FROM debug_logs 
   WHERE function_name = 'delete_member_cascade' 
   ORDER BY timestamp DESC;
   ``` 