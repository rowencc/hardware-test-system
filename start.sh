#!/bin/bash
# 硬件测试记录系统 - 启动脚本
# Hardware Test Record System - Startup Script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"

echo "============================================"
echo "  硬件测试记录系统"
echo "  Hardware Test Record System"
echo "============================================"
echo ""

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 1. 检查 Python
echo -e "${YELLOW}[1/4] 检查 Python 环境...${NC}"
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    echo -e "${GREEN}  ✓ $PYTHON_VERSION${NC}"
else
    echo -e "${RED}  ✗ 未找到 Python3，请先安装 Python 3.9+${NC}"
    exit 1
fi

# 2. 检查依赖
echo -e "${YELLOW}[2/4] 检查 Python 依赖...${NC}"
MISSING_DEPS=()
for pkg in flask flask-cors pymysql sqlalchemy openpyxl markdown python-dotenv; do
    if ! python3 -c "import ${pkg//-/_}" 2>/dev/null; then
        MISSING_DEPS+=("$pkg")
    fi
done

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo -e "${YELLOW}  安装缺失依赖: ${MISSING_DEPS[*]}${NC}"
    python3 -m pip install "${MISSING_DEPS[@]}" 2>&1 | tail -5
fi
echo -e "${GREEN}  ✓ 依赖检查完成${NC}"

# 3. 初始化数据库
echo -e "${YELLOW}[3/4] 初始化数据库...${NC}"

# 检查 ServBay MySQL 是否运行
MYSQL_SOCKET="/Applications/ServBay/tmp/mysql.sock"
MYSQL_PORT=3306

if [ -S "$MYSQL_SOCKET" ]; then
    echo -e "${GREEN}  ✓ ServBay MySQL 已运行${NC}"
    # 使用 socket 连接
    MYSQL_CMD="mysql -u root -S $MYSQL_SOCKET"
elif command -v mysql &> /dev/null; then
    echo -e "${YELLOW}  使用命令行 MySQL 客户端${NC}"
    MYSQL_CMD="mysql -u root -h 127.0.0.1 -P $MYSQL_PORT"
else
    echo -e "${YELLOW}  ⚠ 未找到 mysql 命令行工具，跳过数据库初始化${NC}"
    echo -e "${YELLOW}  请手动执行 database/schema.sql 中的 SQL 语句${NC}"
    MYSQL_CMD=""
fi

if [ -n "$MYSQL_CMD" ]; then
    # 尝试创建数据库和表
    if $MYSQL_CMD < "$PROJECT_DIR/database/schema.sql" 2>/dev/null; then
        echo -e "${GREEN}  ✓ 数据库初始化成功${NC}"
    else
        echo -e "${YELLOW}  ⚠ 数据库初始化可能失败（可能已存在），继续启动...${NC}"
    fi
fi

# 4. 启动后端服务
echo -e "${YELLOW}[4/4] 启动后端服务...${NC}"
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  后端 API: http://127.0.0.1:8000${NC}"
echo -e "${GREEN}  前端页面: 在浏览器中打开 frontend/index.html${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""

cd "$PROJECT_DIR"
python3 backend/app.py