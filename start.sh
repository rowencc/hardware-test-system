#!/bin/bash
# 硬件测试记录系统 - 启动脚本
# 用法: ./start.sh              # 直接启动（前台运行）
#       ./start.sh --service    # 安装并注册为系统服务

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
BACKEND_DIR="$PROJECT_DIR/backend"
PORT="${PORT:-8100}"
SERVICE_NAME="hardware-test"
LOG_FILE="/tmp/hwtest.log"

# 颜色
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "  ${GREEN}✓${NC} $*"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $*"; }
fail() { echo -e "  ${RED}✗${NC} $*"; exit 1; }

echo -e "${BOLD}${CYAN}"
echo "  ==========================================================="
echo "    硬件测试记录系统 - Hardware Test Record System"
echo "  ==========================================================="
echo -e "${NC}"

# ====== 1. 检查 Python ======
PYTHON_BIN=""
for py in python3.11 python3.10 python3.9 python3; do
    if command -v "$py" &>/dev/null; then
        PY_VER=$("$py" -c 'import sys; print(".".join(map(str,sys.version_info[:2])))' 2>/dev/null || true)
        if [ -n "$PY_VER" ] && [ "$(printf '%s\n' "3.9" "$PY_VER" | sort -V | head -1)" = "3.9" ]; then
            PYTHON_BIN="$py"
            break
        fi
    fi
done
if [ -z "$PYTHON_BIN" ]; then
    fail "未找到 Python 3.9+，请先安装"
fi
ok "Python $($PYTHON_BIN --version 2>&1) ($PYTHON_BIN)"

# ====== 2. 检查依赖 ======
MISSING_DEPS=()
for pkg in flask flask-cors pymysql sqlalchemy openpyxl markdown python-dotenv werkzeug; do
    import_name="${pkg//-/_}"
    if ! "$PYTHON_BIN" -c "import $import_name" 2>/dev/null; then
        MISSING_DEPS+=("$pkg")
    fi
done
if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    warn "安装缺失依赖: ${MISSING_DEPS[*]}"
    if ! "$PYTHON_BIN" -m pip install "${MISSING_DEPS[@]}" -q 2>&1; then
        fail "依赖安装失败，请手动执行: $PYTHON_BIN -m pip install ${MISSING_DEPS[*]}"
    fi
    # 验证安装成功
    for pkg in "${MISSING_DEPS[@]}"; do
        import_name="${pkg//-/_}"
        if ! "$PYTHON_BIN" -c "import $import_name" 2>/dev/null; then
            fail "依赖 $pkg 安装后仍无法导入"
        fi
    done
fi
ok "依赖检查完成"

# ====== 3. 初始化数据库 ======
MYSQL_CMD=""
# 优先检测 TCP 连接（跨平台兼容）
if "$PYTHON_BIN" -c "import socket; s=socket.socket(); s.settimeout(2); s.connect(('127.0.0.1', 3306)); s.close()" 2>/dev/null; then
    MYSQL_CMD="mysql -u root -h 127.0.0.1 -P 3306"
elif [ -S "/Applications/ServBay/tmp/mysql.sock" ]; then
    MYSQL_CMD="mysql -u root -S /Applications/ServBay/tmp/mysql.sock"
elif command -v mysql &>/dev/null; then
    MYSQL_CMD="mysql -u root -h 127.0.0.1 -P 3306"
fi

if [ -n "$MYSQL_CMD" ]; then
    if $MYSQL_CMD < "$PROJECT_DIR/database/schema.sql" 2>/dev/null; then
        ok "数据库初始化成功"
    else
        warn "数据库初始化可能已存在，继续..."
    fi
else
    warn "未找到可用的 MySQL 连接，跳过数据库初始化"
fi

# ====== 4. 端口检测 ======
PORT_IN_USE=false
if command -v lsof &>/dev/null; then
    if lsof -ti:"$PORT" &>/dev/null; then
        PORT_IN_USE=true
    fi
elif command -v fuser &>/dev/null; then
    if fuser "${PORT}/tcp" &>/dev/null 2>&1; then
        PORT_IN_USE=true
    fi
fi

if [ "$PORT_IN_USE" = true ]; then
    warn "端口 $PORT 已被占用:"
    if command -v lsof &>/dev/null; then
        lsof -i:"$PORT" 2>/dev/null | head -5
    elif command -v ss &>/dev/null; then
        ss -tlnp | grep ":$PORT " || true
    fi
    echo ""
    if [ "$1" != "--service" ]; then
        read -rp "端口 $PORT 被占用，是否停止占用进程并继续？[y/N]: " KILL_ANS
        case "$KILL_ANS" in
            [Yy]|[Yy][Ee][Ss])
                PIDS=$(lsof -ti:"$PORT" 2>/dev/null || fuser "${PORT}/tcp" 2>/dev/null || true)
                if [ -n "$PIDS" ]; then
                    for pid in $PIDS; do
                        kill "$pid" 2>/dev/null || true
                    done
                    sleep 2
                    ok "已停止占用进程"
                fi
                ;;
            *)
                fail "请先手动释放端口 $PORT 或设置 PORT 环境变量指定其他端口"
                ;;
        esac
    fi
fi

# ====== 5. 是否注册为系统服务 ======
INSTALL_SERVICE=false
if [ "$1" = "--service" ]; then
    INSTALL_SERVICE=true
fi

if [ "$INSTALL_SERVICE" = false ] && [ "$(uname)" = "Linux" ] && command -v systemctl &>/dev/null; then
    echo ""
    read -rp "是否安装为系统服务（开机自启动）？[y/N]: " ANSWER
    case "$ANSWER" in
        [Yy]|[Yy][Ee][Ss]) INSTALL_SERVICE=true ;;
    esac
fi

if [ "$INSTALL_SERVICE" = true ]; then
    if [ "$(uname)" != "Linux" ] || ! command -v systemctl &>/dev/null; then
        warn "当前系统不支持 systemd，改为普通启动"
        INSTALL_SERVICE=false
    fi
fi

# ====== 6. 安装 systemd 服务 ======
if [ "$INSTALL_SERVICE" = true ]; then
    echo ""
    echo -e "${BOLD}${CYAN}==> 安装系统服务${NC}"

    SVC_USER="${SUDO_USER:-$USER}"
    if [ "$SVC_USER" = "root" ]; then
        for u in www-data nginx nobody; do
            if id "$u" &>/dev/null 2>&1; then
                SVC_USER="$u"
                break
            fi
        done
    fi

    SVC_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
    sudo tee "$SVC_FILE" > /dev/null <<SVCEOF
[Unit]
Description=Hardware Test Record System
After=network.target mysqld.service mariadb.service
Wants=mysqld.service

[Service]
Type=simple
User=${SVC_USER}
Group=${SVC_USER}
WorkingDirectory=${PROJECT_DIR}
EnvironmentFile=-${PROJECT_DIR}/.env
Environment=PORT=${PORT}
ExecStart=${PROJECT_DIR}/venv/bin/python3 ${BACKEND_DIR}/app.py
Restart=on-failure
RestartSec=5
NoNewPrivileges=yes
PrivateTmp=yes

[Install]
WantedBy=multi-user.target
SVCEOF

    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVICE_NAME" 2>/dev/null
    sudo systemctl restart "$SERVICE_NAME"
    sleep 3

    if sudo systemctl is-active --quiet "$SERVICE_NAME"; then
        ok "服务安装成功并已启动"
        ok "开机自启动已启用"
    else
        warn "服务启动可能失败"
        echo "  检查: sudo journalctl -u $SERVICE_NAME -n 20 --no-pager"
        echo "  状态: sudo systemctl status $SERVICE_NAME --no-pager"
    fi

    echo ""
    echo -e "${BOLD}服务管理命令:${NC}"
    echo "  sudo systemctl status  $SERVICE_NAME   # 查看状态"
    echo "  sudo systemctl restart $SERVICE_NAME   # 重启"
    echo "  sudo systemctl stop    $SERVICE_NAME   # 停止"
    echo "  sudo journalctl -u $SERVICE_NAME -f    # 实时日志"
    echo "  sudo systemctl disable $SERVICE_NAME   # 取消自启动"
else
    # ====== 7. 普通启动（前台） ======
    echo ""
    echo -e "${BOLD}${CYAN}==> 前台启动${NC}"
    echo -e "  后端 API: ${GREEN}http://127.0.0.1:${PORT}${NC}"
    echo -e "  前端页面: 在浏览器中打开 frontend/index.html"
    echo -e "  停止服务: Ctrl+C"
    echo ""

    cd "$BACKEND_DIR"
    exec "$PYTHON_BIN" app.py
fi
