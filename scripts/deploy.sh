#!/bin/bash
# =============================================================================
# 硬件测试记录系统 — 一键部署脚本 v2
# 支持: CentOS 8+ / Ubuntu 22.04+ / Debian 12+ / Alibaba Cloud Linux 3+
# 用法:
#   sudo bash deploy.sh                              # 默认 /www/wwwroot/hardware-test-system
#   sudo bash deploy.sh /opt/hardware-test-system     # 自定义安装目录
#   sudo bash deploy.sh --mysql-password=yourpass     # 传入 MySQL 密码
#   sudo bash deploy.sh -p yourpass                   # 传入 MySQL 密码(短选项)
#   sudo bash deploy.sh --service                     # 跳过交互，直接安装 systemd 服务
#   sudo bash deploy.sh --no-service                  # 跳过交互，不安装 systemd 服务
#   sudo bash deploy.sh --nginx                       # 跳过交互，直接配置 Nginx
#   sudo bash deploy.sh --no-nginx                    # 跳过交互，不配置 Nginx
#   PORT=8100 sudo bash deploy.sh                     # 自定义端口
#   sudo bash deploy.sh restart                       # 重启服务
#   sudo bash deploy.sh status                        # 查看服务状态
#   sudo bash deploy.sh stop                          # 停止服务
# =============================================================================

set -e

# ---- 路径解析 ----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SCRIPT_NAME="$(basename "$0")"

# ---- 参数解析 ----
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-}"
INSTALL_DIR=""
INSTALL_SERVICE=""
INSTALL_NGINX=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mysql-password=*)
            MYSQL_ROOT_PASSWORD="${1#*=}"
            shift
            ;;
        --mysql-password|-p)
            MYSQL_ROOT_PASSWORD="$2"
            shift 2
            ;;
        --service)
            INSTALL_SERVICE="Y"
            shift
            ;;
        --no-service)
            INSTALL_SERVICE="N"
            shift
            ;;
        --nginx)
            INSTALL_NGINX="Y"
            shift
            ;;
        --no-nginx)
            INSTALL_NGINX="N"
            shift
            ;;
        restart|status|stop)
            if command -v systemctl &>/dev/null && systemctl is-enabled hardware-test.service &>/dev/null 2>&1; then
                systemctl "$1" hardware-test.service
                exit $?
            else
                echo "systemd 服务未安装或未启用，无法执行 $1 命令"
                exit 1
            fi
            ;;
        -*)
            echo "未知参数: $1"
            echo "用法: sudo bash $SCRIPT_NAME [安装目录] [--mysql-password=密码] [--service|--no-service] [--nginx|--no-nginx]"
            echo "管理命令: sudo bash $SCRIPT_NAME restart|status|stop"
            exit 1
            ;;
        *)
            INSTALL_DIR="$1"
            shift
            ;;
    esac
done
INSTALL_DIR="${INSTALL_DIR:-/www/wwwroot/hardware-test-system}"
BACKEND_PORT="${PORT:-8100}"

# ---- 颜色 ----
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
BOLD='\033[1m'; NC='\033[0m'

step() { echo -e "\n${BOLD}${CYAN}==> $*${NC}"; }
ok()   { echo -e "    ${GREEN}✓${NC} $*"; }
warn() { echo -e "    ${YELLOW}⚠${NC} $*"; }
fail() { echo -e "    ${RED}✗${NC} $*"; exit 1; }
info() { echo -e "    ${CYAN}ℹ${NC} $*"; }

# ---- 权限检查 ----
if [ "$EUID" -ne 0 ] && [ "$(uname)" != "Darwin" ]; then
    echo -e "${RED}请使用 sudo 运行此脚本${NC}"
    exit 1
fi

echo -e "${BOLD}${CYAN}"
echo "  ==========================================================="
echo "    硬件测试记录系统 — 一键部署 v2"
echo "  ==========================================================="
echo -e "${NC}"
echo "  安装目录: ${INSTALL_DIR}"
echo "  后端端口: ${BACKEND_PORT}"
echo ""

# ====== 0. OS 检测 ======
step "0/7  检测操作系统"

OS_ID=""
OS_VERSION=""
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="$ID"
    OS_VERSION="$VERSION_ID"
elif [ -f /etc/alinux-release ]; then
    OS_ID="alinux"
    OS_VERSION="3"
fi

case "$OS_ID" in
    centos|rhel|fedora|rocky|almalinux)
        PKG_MGR="dnf"
        ok "操作系统: ${OS_ID} ${OS_VERSION} (dnf)"
        ;;
    alinux)
        PKG_MGR="dnf"
        ok "操作系统: Alibaba Cloud Linux ${OS_VERSION} (dnf)"
        ;;
    ubuntu|debian)
        PKG_MGR="apt"
        ok "操作系统: ${OS_ID} ${OS_VERSION} (apt)"
        ;;
    *)
        warn "未知操作系统: ${OS_ID:-unknown}"
        PKG_MGR="auto"
        ;;
esac

# ====== 1. 系统依赖检查 & 安装 ======
step "1/7  检查系统环境"

PYTHON_READY=false
PYTHON_CMD=""

# 先尝试已有的 python3
for py in python3.11 python3.10 python3.9 python3; do
    if command -v "$py" &>/dev/null; then
        PY_VER=$("$py" -c 'import sys; print(".".join(map(str,sys.version_info[:2])))' 2>/dev/null || true)
        if [ -n "$PY_VER" ] && [ "$(printf '%s\n' "3.9" "$PY_VER" | sort -V | head -1)" = "3.9" ]; then
            PYTHON_CMD="$py"
            PYTHON_READY=true
            ok "Python ${PY_VER} ($py)"
            break
        fi
    fi
done

# 没有合格 Python，尝试安装
if ! $PYTHON_READY; then
    warn "未找到 Python 3.9+，尝试安装..."
    case "$PKG_MGR" in
        dnf)
            dnf install -y python3.11 python3.11-devel python3.11-pip 2>/dev/null || \
            dnf install -y python39 python39-devel python39-pip 2>/dev/null || \
            fail "无法通过 dnf 安装 Python 3.9+"
            # 重新探测
            for py in python3.11 python3.10 python3.9; do
                if command -v "$py" &>/dev/null; then
                    PYTHON_CMD="$py"
                    PYTHON_READY=true
                    ok "Python $("$py" --version 2>&1) 安装成功"
                    break
                fi
            done
            ;;
        apt)
            apt update -qq
            apt install -y -qq python3 python3-pip python3-venv 2>/dev/null || \
            fail "无法通过 apt 安装 Python 3"
            PYTHON_CMD="python3"
            PYTHON_READY=true
            ok "Python $("$PYTHON_CMD" --version 2>&1) 安装成功"
            ;;
        *)
            fail "无法自动安装 Python，请手动安装 Python 3.9+ 后重试"
            ;;
    esac
fi

# pip 可用性
if ! "$PYTHON_CMD" -m pip --version &>/dev/null; then
    case "$PKG_MGR" in
        dnf) dnf install -y python3.11-pip 2>/dev/null || dnf install -y python39-pip 2>/dev/null ;;
        apt) apt install -y -qq python3-pip 2>/dev/null ;;
    esac
fi

ok "Python pip 可用"

# MySQL 检查
MYSQL_READY=false
MYSQL_CMD=""
if command -v mysql &>/dev/null; then
    MYSQL_CMD="mysql"
    # 检查是否可连接（无密码本地）
    if mysql -u root -e "SELECT 1" &>/dev/null 2>&1; then
        ok "MySQL 已运行 (root 免密连接)"
        MYSQL_READY=true
    elif [ -n "$MYSQL_ROOT_PASSWORD" ] && mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT 1" &>/dev/null 2>&1; then
        ok "MySQL 已运行 (环境变量密码)"
        MYSQL_READY=true
    else
        warn "MySQL 需要密码连接，请设置 MYSQL_ROOT_PASSWORD 环境变量"
        echo "    示例: MYSQL_ROOT_PASSWORD=yourpass sudo bash $SCRIPT_NAME"
    fi
else
    warn "未安装 MySQL 客户端，数据库初始化将跳过"
fi

# ====== 2. 项目部署 ======
step "2/7  部署项目文件"

if [ "$PROJECT_DIR" != "$INSTALL_DIR" ]; then
    mkdir -p "$INSTALL_DIR"
    if command -v rsync &>/dev/null; then
        rsync -a --exclude='venv/' --exclude='__pycache__/' --exclude='*.pyc' \
            --exclude='.git/' --exclude='node_modules/' \
            "$PROJECT_DIR/" "$INSTALL_DIR/"
        ok "项目已同步到 $INSTALL_DIR (rsync)"
    else
        warn "rsync 不可用，降级为 cp -r"
        shopt -s dotglob
        cp -r "$PROJECT_DIR"/* "$INSTALL_DIR/" 2>/dev/null || true
        shopt -u dotglob
        ok "项目已同步到 $INSTALL_DIR (cp)"
    fi
    PROJECT_DIR="$INSTALL_DIR"
else
    ok "项目已在目标路径"
fi

cd "$PROJECT_DIR"

# ====== 3. 虚拟环境 & 依赖 ======
step "3/7  安装 Python 依赖"

if [ ! -d "venv" ]; then
    "$PYTHON_CMD" -m venv venv
    ok "虚拟环境已创建"
else
    ok "虚拟环境已存在"
fi

source venv/bin/activate
pip install --upgrade pip -q 2>/dev/null || true

# 安装依赖（带重试，通过 import 验证而非 grep error 文本）
RETRY=0
INSTALL_OK=false
while [ $RETRY -lt 3 ]; do
    if pip install -r requirements.txt -q 2>&1; then
        # 验证关键包可导入
        if python -c "import flask, flask_cors, pymysql, sqlalchemy, openpyxl" 2>/dev/null; then
            INSTALL_OK=true
            break
        fi
    fi
    RETRY=$((RETRY+1))
    warn "依赖安装验证失败，重试 ($RETRY/3)..."
    sleep 2
done

if [ "$INSTALL_OK" = false ]; then
    fail "依赖安装失败，请手动执行: pip install -r requirements.txt"
fi
ok "Python 依赖安装完成"

# ====== 4. .env 配置 ======
step "4/7  配置环境变量 (.env)"

NEED_ENV=false
if [ -f ".env" ]; then
    ok ".env 已存在"
else
    NEED_ENV=true
fi

# 检查 .env 是否包含所需全部变量
if ! $NEED_ENV; then
    for var in DB_HOST DB_PORT DB_USER DB_PASSWORD DB_DATABASE SECRET_KEY; do
        if ! grep -q "^${var}=" .env 2>/dev/null; then
            NEED_ENV=true
            break
        fi
    done
fi

if $NEED_ENV; then
    info "配置数据库连接信息（回车使用默认值）:"
    echo ""
    read -p "    数据库主机 [127.0.0.1]: " DB_HOST
    DB_HOST=${DB_HOST:-127.0.0.1}
    read -p "    数据库端口 [3306]: " DB_PORT
    DB_PORT=${DB_PORT:-3306}
    read -p "    数据库用户 [root]: " DB_USER
    DB_USER=${DB_USER:-root}
    read -sp "    数据库密码: " DB_PASSWORD
    echo ""
    read -p "    数据库名称 [hardware]: " DB_NAME
    DB_NAME=${DB_NAME:-hardware}

    SECRET_KEY=$("$PYTHON_CMD" -c "import secrets; print(secrets.token_hex(32))")

    cat > .env <<PYEOF
# Hardware Test System — 环境变量配置
# 密码含特殊字符时直接填写原始密码，应用会自动 URL 编码
DB_HOST=${DB_HOST}
DB_PORT=${DB_PORT}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
DB_DATABASE=${DB_NAME}
SECRET_KEY=${SECRET_KEY}
PYEOF
    chmod 600 .env
    ok ".env 已创建 (权限 600)"
fi

# ====== 5. 数据库初始化 ======
step "5/7  初始化数据库"

# 读取 .env 获取数据库信息
DB_HOST=$(grep '^DB_HOST=' .env 2>/dev/null | cut -d= -f2-)
DB_PORT=$(grep '^DB_PORT=' .env 2>/dev/null | cut -d= -f2-)
DB_USER=$(grep '^DB_USER=' .env 2>/dev/null | cut -d= -f2-)
DB_PASSWORD=$(grep '^DB_PASSWORD=' .env 2>/dev/null | cut -d= -f2-)
DB_NAME=$(grep '^DB_DATABASE=' .env 2>/dev/null | cut -d= -f2-)

DB_HOST=${DB_HOST:-127.0.0.1}
DB_PORT=${DB_PORT:-3306}
DB_USER=${DB_USER:-root}
DB_NAME=${DB_NAME:-hardware}

# 构建 MySQL 连接参数
MYSQL_CONN="-h $DB_HOST -P $DB_PORT -u $DB_USER"
if [ -n "$DB_PASSWORD" ]; then
    MYSQL_CONN="$MYSQL_CONN -p$DB_PASSWORD"
fi

# 尝试连接
if mysql $MYSQL_CONN -e "SELECT 1" &>/dev/null 2>&1; then
    ok "MySQL 连接成功 ($DB_USER@$DB_HOST:$DB_PORT)"

    # 创建数据库
    mysql $MYSQL_CONN -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null
    ok "数据库 ${DB_NAME} 已就绪"

    # 导入表结构
    if [ -f "database/schema.sql" ]; then
        mysql $MYSQL_CONN "$DB_NAME" < database/schema.sql 2>/dev/null
        ok "数据表已导入 (database/schema.sql)"
    else
        warn "未找到 database/schema.sql"
    fi
else
    warn "无法连接 MySQL，跳过数据库初始化"
    echo "    手动执行: mysql -u $DB_USER -p -h $DB_HOST -P $DB_PORT < database/schema.sql"
fi

# ====== 6. systemd 服务 ======
step "6/7  配置 systemd 服务"

if [ "$(uname)" = "Linux" ] && command -v systemctl &>/dev/null; then
    # 根据 --service / --no-service 参数决定是否安装
    if [ -z "$INSTALL_SERVICE" ]; then
        echo -n "    是否安装 systemd 服务? [Y/n] "
        read -r SVC_ANS
        INSTALL_SERVICE=${SVC_ANS:-Y}
    fi

    if [[ "$INSTALL_SERVICE" =~ ^[Yy] ]]; then
        # 自动检测运行用户
        if [ -n "$SUDO_USER" ]; then
            SVC_USER="$SUDO_USER"
        elif id www-data &>/dev/null 2>&1; then
            SVC_USER="www-data"
        elif id nginx &>/dev/null 2>&1; then
            SVC_USER="nginx"
        else
            SVC_USER="root"
        fi

        cat > /etc/systemd/system/hardware-test.service <<SVCEOF
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
Environment="PATH=${PROJECT_DIR}/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=${PROJECT_DIR}/venv/bin/python3 ${PROJECT_DIR}/backend/app.py
Restart=on-failure
RestartSec=5
NoNewPrivileges=yes
PrivateTmp=yes

[Install]
WantedBy=multi-user.target
SVCEOF
        systemctl daemon-reload
        systemctl enable hardware-test.service 2>/dev/null || true
        ok "systemd 服务已安装"

        systemctl restart hardware-test.service 2>/dev/null || \
            systemctl start hardware-test.service 2>/dev/null || \
            warn "服务启动失败"
        sleep 2
        if systemctl is-active --quiet hardware-test.service 2>/dev/null; then
            ok "服务已启动"
        else
            warn "服务未运行，检查日志: journalctl -u hardware-test.service -n 20"
        fi
    else
        info "跳过 systemd 服务安装"
    fi
else
    warn "非 Linux 环境，跳过 systemd 配置"
fi

# ====== 7. Nginx 反向代理 ======
step "7/7  配置 Nginx 反向代理"

if command -v nginx &>/dev/null; then
    if [ -z "$INSTALL_NGINX" ]; then
        echo -n "    是否配置 Nginx 反向代理? [y/N] "
        read -r NGX_ANS
        INSTALL_NGINX=${NGX_ANS:-N}
    fi

    if [[ "$INSTALL_NGINX" =~ ^[Yy] ]]; then
        if [ -z "$DOMAIN" ]; then
            read -p "    输入域名 (留空则 _ 通配): " DOMAIN
        fi
        SERVER_NAME="${DOMAIN:-_}"

        # 检测宝塔面板路径
        NGINX_CONF_DIR=""
        if [ -d "/www/server/panel/vhost/nginx" ]; then
            info "检测到宝塔面板"
            if [ -n "$DOMAIN" ] && [ "$DOMAIN" != "_" ]; then
                NGINX_CONF_DIR="/www/server/panel/vhost/nginx/extension/${DOMAIN}"
                mkdir -p "$NGINX_CONF_DIR"
                NGINX_CONF="${NGINX_CONF_DIR}/hardware-test.conf"
            else
                NGINX_CONF="/etc/nginx/conf.d/hardware-test.conf"
            fi
        else
            NGINX_CONF="/etc/nginx/conf.d/hardware-test.conf"
        fi

        # 备份旧配置
        if [ -f "$NGINX_CONF" ]; then
            cp "$NGINX_CONF" "${NGINX_CONF}.bak.$(date +%Y%m%d%H%M%S)"
            info "已备份旧配置 → ${NGINX_CONF}.bak.*"
        fi

        cat > "$NGINX_CONF" <<NGXEOF
upstream hardware_test_backend {
    server 127.0.0.1:${BACKEND_PORT};
    keepalive 16;
}

server {
    listen 80;
    server_name ${SERVER_NAME};
    client_max_body_size 50m;

    access_log /var/log/nginx/hardware-test-access.log;
    error_log /var/log/nginx/hardware-test-error.log;

    location / {
        root ${PROJECT_DIR}/frontend;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }

    location /api/ {
        proxy_pass http://hardware_test_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 120s;
        proxy_send_timeout 120s;
    }

    location ~* \.(ico|css|js|gif|jpe?g|png|woff2?)$ {
        root ${PROJECT_DIR}/frontend;
        expires 7d;
        add_header Cache-Control "public, immutable";
    }
}
NGXEOF
        # 验证配置语法，失败则恢复备份
        if nginx -t 2>/dev/null; then
            systemctl reload nginx 2>/dev/null || service nginx reload 2>/dev/null || true
            ok "Nginx 配置完成 → ${NGINX_CONF}"
        else
            # 恢复备份
            LATEST_BAK=$(ls -t "${NGINX_CONF}".bak.* 2>/dev/null | head -1)
            if [ -n "$LATEST_BAK" ]; then
                cp "$LATEST_BAK" "$NGINX_CONF"
                warn "Nginx 配置语法错误，已恢复备份"
            else
                warn "Nginx 配置语法错误，无备份可恢复"
            fi
            fail "请检查 Nginx 配置后重试"
        fi
    fi
else
    warn "Nginx 未安装"
fi

# ====== 完成：自动验证 ======
echo ""
echo -e "${GREEN}${BOLD}"
echo "  ==========================================================="
echo "    部署完成！"
echo "  ==========================================================="
echo -e "${NC}"

echo "  自动验证..."

# 验证后端端口
if command -v ss &>/dev/null; then
    PORT_OK=$(ss -tlnp 2>/dev/null | grep -c ":${BACKEND_PORT} " || true)
elif command -v lsof &>/dev/null; then
    PORT_OK=$(lsof -i:"${BACKEND_PORT}" 2>/dev/null | grep -c LISTEN || true)
else
    PORT_OK=0
fi

# 验证 health API
HEALTH_OK=0
if curl -sf -o /dev/null "http://127.0.0.1:${BACKEND_PORT}/api/health" 2>/dev/null; then
    HEALTH_OK=1
fi

echo "  端口 ${BACKEND_PORT}:  $([ "$PORT_OK" -gt 0 ] && echo -e '${GREEN}监听中${NC}' || echo -e '${RED}未监听${NC}')"
echo "  健康检查:          $([ "$HEALTH_OK" -eq 1 ] && echo -e '${GREEN}正常${NC}' || echo -e '${RED}异常${NC}')"

if [ "$PORT_OK" -eq 0 ] || [ "$HEALTH_OK" -eq 0 ]; then
    echo ""
    warn "服务可能未正常运行，请检查:"
    echo "    systemctl status hardware-test.service"
    echo "    journalctl -u hardware-test.service -n 20 --no-pager"
fi

echo ""
echo "  安装目录:   ${PROJECT_DIR}"
echo "  后端端口:   ${BACKEND_PORT}"
echo "  健康检查:   curl http://127.0.0.1:${BACKEND_PORT}/api/health"
echo ""
echo "  管理命令:"
echo "    systemctl status  hardware-test.service    # 服务状态"
echo "    systemctl restart hardware-test.service    # 重启"
echo "    journalctl -u hardware-test.service -f     # 实时日志"
echo ""
echo -e "${GREEN}${BOLD}"
echo "  ==========================================================="
echo "    部署完成！"
echo "  ==========================================================="
echo -e "${NC}"
echo "  安装目录:   ${PROJECT_DIR}"
echo "  后端端口:   ${BACKEND_PORT}"
echo "  健康检查:   curl http://127.0.0.1:${BACKEND_PORT}/api/commands?search="
echo ""
echo "  管理命令:"
echo "    systemctl status  hardware-test.service    # 服务状态"
echo "    systemctl restart hardware-test.service    # 重启"
echo "    journalctl -u hardware-test.service -f     # 实时日志"
echo ""
echo "  详情: ${PROJECT_DIR}/output/DEPLOY.md"
echo ""

