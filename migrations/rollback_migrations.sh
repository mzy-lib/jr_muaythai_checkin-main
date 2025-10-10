#!/bin/bash

# 设置环境变量
source ../.env

# 检查数据库连接
echo "正在检查数据库连接..."
psql "$DATABASE_URL" -c "SELECT 1" > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "数据库连接失败，请检查环境变量"
  exit 1
fi

# 检查迁移表是否存在
echo "正在检查迁移表..."
table_exists=$(psql "$DATABASE_URL" -t -c "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'migrations')")
if [[ $table_exists != *t* ]]; then
  echo "迁移表不存在，无需回滚"
  exit 0
fi

# 获取最后一次迁移
last_migration=$(psql "$DATABASE_URL" -t -c "SELECT name FROM migrations ORDER BY id DESC LIMIT 1")
last_migration=$(echo $last_migration | xargs)  # 去除空白字符

if [ -z "$last_migration" ]; then
  echo "没有找到已应用的迁移"
  exit 0
fi

echo "最后一次迁移: $last_migration"

# 询问用户是否回滚
read -p "是否回滚此迁移? (y/n): " confirm
if [ "$confirm" != "y" ]; then
  echo "回滚已取消"
  exit 0
fi

# 执行回滚
echo "正在回滚迁移: $last_migration"

# 找到对应的迁移文件
migration_file="${last_migration}.sql"
if [ ! -f "$migration_file" ]; then
  echo "找不到迁移文件: $migration_file"
  exit 1
fi

# 提取回滚SQL
rollback_sql=$(sed -n '/-- 向下迁移/,$ p' "$migration_file" | grep -v "^--" | grep -v "^$")

if [ -z "$rollback_sql" ]; then
  echo "找不到回滚SQL"
  exit 1
fi

# 执行回滚SQL
echo "$rollback_sql" | psql "$DATABASE_URL"

# 从迁移表中删除记录
psql "$DATABASE_URL" -c "DELETE FROM migrations WHERE name = '$last_migration'"

echo "回滚完成: $last_migration" 