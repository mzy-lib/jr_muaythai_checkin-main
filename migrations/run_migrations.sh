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

# 创建迁移表（如果不存在）
echo "正在创建迁移表..."
psql "$DATABASE_URL" -c "
CREATE TABLE IF NOT EXISTS migrations (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  applied_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
"

# 执行迁移
run_migration() {
  local file=$1
  local name=$(basename "$file" .sql)
  
  # 检查迁移是否已应用
  local applied=$(psql "$DATABASE_URL" -t -c "SELECT COUNT(*) FROM migrations WHERE name = '$name'")
  
  if [ "$applied" -eq "0" ]; then
    echo "正在应用迁移: $name"
    psql "$DATABASE_URL" -f "$file"
    
    # 记录迁移
    psql "$DATABASE_URL" -c "INSERT INTO migrations (name) VALUES ('$name')"
    
    echo "迁移完成: $name"
  else
    echo "迁移已应用: $name"
  fi
}

# 按顺序执行所有迁移
for file in $(ls -1 *.sql | sort); do
  run_migration "$file"
done

echo "所有迁移已完成" 