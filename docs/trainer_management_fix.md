# 教练管理修复文档

## 问题描述

教练管理页面存在以下问题：

1. 数据库中存在多个重名的教练（如多个"JR"、"Da"和"Ming"）
2. 前端组件使用硬编码的教练列表，而不是从数据库动态获取
3. 不同组件使用不同的教练列表，导致数据不一致

## 解决方案

### 1. 数据库修复

- 清理数据库中的重复教练，保留最早创建的每个名称的教练记录
- 删除不在文档中的教练（如TestTrainer）
- 为trainers表的name字段添加唯一性约束，防止将来出现重复

### 2. 前端修复

- 创建一个统一的教练数据获取钩子（useTrainers），从数据库动态获取教练列表
- 修改PrivateClassFields.tsx和CheckInRecordsList.tsx，使用这个钩子获取教练列表，而不是使用硬编码的列表

## 执行的更改

### 数据库更改

1. 创建并执行了清理脚本（clean_duplicate_trainers.sql）：
   - 删除了不在文档中的教练（TestTrainer）
   - 对于每个教练名称，保留最早创建的记录，删除其他重复记录
   - 添加了唯一性约束，防止将来出现重复

2. 创建了迁移文件（20250302000000_fix_duplicate_trainers.sql）：
   - 添加了唯一性约束
   - 添加了表和列的注释

### 前端更改

1. 创建了useTrainers钩子（src/hooks/useTrainers.ts）：
   - 从数据库获取教练列表
   - 提供加载状态和错误处理

2. 修改了PrivateClassFields组件（src/components/member/PrivateClassFields.tsx）：
   - 使用useTrainers钩子获取教练列表，而不是使用硬编码的列表
   - 添加了加载状态和错误处理

3. 修改了CheckInRecordsList组件（src/components/admin/CheckInRecordsList.tsx）：
   - 使用useTrainers钩子获取教练列表，而不是使用硬编码的列表
   - 添加了加载状态和错误处理

## 结果

1. 数据库中现在只有7个教练，符合文档要求：
   - JR类教练1名：JR
   - Senior类教练6名：Da, Ming, Big, Bas, Sumay, First

2. 前端组件现在从数据库动态获取教练列表，确保数据一致性

3. 添加了唯一性约束，防止将来出现重复教练

## 注意事项

1. 如果需要添加新教练，请确保名称不与现有教练重复

2. 如果需要修改教练信息，请使用教练管理页面，而不是直接修改数据库 