#!/bin/bash

# 设置颜色输出
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}开始泰拳馆签到系统测试...${NC}"

# 检查Cypress是否安装
if ! [ -x "$(command -v npx)" ]; then
  echo -e "${RED}错误: npx 未安装，请先安装Node.js和npm${NC}" >&2
  exit 1
fi

# 检查应用是否正在运行
echo -e "${YELLOW}检查应用是否运行中...${NC}"
if ! curl -s http://localhost:3000 > /dev/null; then
  echo -e "${RED}错误: 应用未运行，请先启动应用${NC}" >&2
  echo -e "${YELLOW}您可以运行: npm run dev${NC}"
  exit 1
fi

# 运行Cypress测试
echo -e "${YELLOW}运行端到端测试...${NC}"

# 选择测试模式
if [ "$1" == "--headless" ]; then
  echo -e "${YELLOW}以无头模式运行测试...${NC}"
  npx cypress run --spec "cypress/e2e/check-in-scenarios.cy.js"
else
  echo -e "${YELLOW}以交互模式运行测试...${NC}"
  npx cypress open --e2e
fi

# 检查测试结果
if [ $? -eq 0 ]; then
  echo -e "${GREEN}所有测试通过!${NC}"
  exit 0
else
  echo -e "${RED}测试失败!${NC}"
  exit 1
fi 