# 硬件测试记录系统 — 部署文档

## 1. 环境要求

| 组件 | 最低版本 | 说明 |
|------|---------|------|
| Python | 3.9+ | 推荐 3.11+ |
| MySQL | 5.7+ | 或 MariaDB 10.3+，需 utf8mb4 支持 |
| pip | 21.0+ | Python 包管理器 |
| Nginx | 1.18+ | 反向代理（可选，生产环境推荐） |
| Git | 2.0+ | 获取源码 |

> **支持系统**: CentOS 8+ / Ubuntu 22.04+ / Debian 12+ / Alibaba Cloud Linux 3+

---

## 2. 项目结构

```
hardware-test-system/
├── backend/
│   └── app.py              # Flask 后端应用（默认端口 8100）
├── frontend/
│   └── index.html          # 单页面前端
├── database/
│   └── schema.sql          # 数据库初始化 DDL
├── output/
│   └── DEPLOY.md           # 本文档
├── scripts/
│   └── deploy.sh           # 一键部署脚本 v2
├── requirements.txt        # Python 依赖
├── .env                    # 环境变量配置（部署时自动生成）
└── start.sh                # 本地开发启动脚本
```

---

## 3. 快速部署

### 3.1 获取代码

```bash
git clone <repo-url> /www/wwwroot/hardware-test-system
cd /www/wwwroot/hardware-test-system
```

### 3.2 一键部署

```bash
chmod +x scripts/deploy.sh

# 默认安装路径与端口
sudo bash scripts/deploy.sh

# 自定义安装路径或端口
sudo bash scripts/deploy.sh /opt/my-custom-path
PORT=8100 sudo bash scripts/deploy.sh

# 预设 MySQL root 密码
MYSQL_ROOT_PASSWORD=yourpass sudo bash scripts/deploy.sh
```

脚本自动完成 7 个步骤：
0. 操作系统检测（自动适配 dnf/apt）
1. Python 3.9+ 环境检查与安装（Alibaba Cloud Linux 自动安装 python3.11）
2. 项目文件同步到安装目录
3. 创建 Python 虚拟环境并安装全部依赖
4. 交互式引导创建 `.env` 配置文件
5. 初始化 MySQL 数据库（建库 + 导入 schema.sql）
6. 可选安装 systemd 服务并启动
7. 可选配置 Nginx 反向代理（自动检测宝塔面板路径）

---

## 4. 手动部署步骤

### 4.1 安装系统依赖

**CentOS/RHEL 8+ / Alibaba Cloud Linux 3+**：
```bash
dnf install -y python3.11 python3.11-devel python3.11-pip mysql-server nginx
```

**Ubuntu 22.04+**：
```bash
apt update
apt install -y python3 python3-pip python3-venv mysql-server nginx
```

**macOS（开发环境）**：
```bash
brew install python@3.12 mysql
```

### 4.2 创建 Python 虚拟环境（推荐）

```bash
cd /opt/hardware-test-system
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

### 4.3 配置 .env 文件

在项目根目录创建 `.env` 文件：

```bash
# 数据库配置
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=hts_user
DB_PASSWORD=your_secure_password_here
DB_DATABASE=hardware

# Flask 密钥 — 务必修改为随机字符串
# 生成方式: python3 -c "import secrets; print(secrets.token_hex(32))"
SECRET_KEY=change_me_to_a_random_64_char_hex_string

# 可选：日志级别
# LOG_LEVEL=INFO
```

> **密码特殊字符注意**：如果密码包含 `@ : / ? #` 等 URL 保留字符，请直接填写原始密码。
> 应用启动时会自动通过 `quote_plus()` 对密码进行 URL 编码，无需手动转义。

### 4.4 初始化数据库

**创建数据库和用户**：

```sql
-- 以 root 身份登录 MySQL
mysql -u root -p

-- 创建数据库
CREATE DATABASE IF NOT EXISTS hardware
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 创建专用用户（将密码替换为 .env 中设置的密码）
CREATE USER IF NOT EXISTS 'hts_user'@'127.0.0.1'
    IDENTIFIED BY 'your_secure_password_here';

GRANT ALL PRIVILEGES ON hardware.* TO 'hts_user'@'127.0.0.1';
FLUSH PRIVILEGES;
EXIT;
```

**导入表结构**：

```bash
mysql -u hts_user -p -h 127.0.0.1 hardware < database/schema.sql
```

> 应用首次启动时也会通过 SQLAlchemy `create_all` 自动建表，但 `schema.sql` 中的视图和存储过程需要手动导入。

### 4.5 启动应用

**直接启动（前台运行，便于调试）**：

```bash
cd /opt/hardware-test-system
source venv/bin/activate
python3 backend/app.py
```

访问 `http://127.0.0.1:8100/api/commands?search=` 验证 API 是否正常。

---

## 5. 生产环境配置

### 5.1 systemd 服务配置

创建 `/etc/systemd/system/hardware-test.service`：

```ini
[Unit]
Description=Hardware Test Record System
After=network.target mysql.service
Wants=mysql.service

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/www/wwwroot/hardware-test-system
Environment="PATH=/www/wwwroot/hardware-test-system/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=/www/wwwroot/hardware-test-system/venv/bin/python3 /www/wwwroot/hardware-test-system/backend/app.py
Restart=on-failure
RestartSec=5

# 安全加固
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/www/wwwroot/hardware-test-system/exports
ReadOnlyPaths=/www/wwwroot/hardware-test-system

[Install]
WantedBy=multi-user.target
```

激活服务：

```bash
sudo systemctl daemon-reload
sudo systemctl enable hardware-test.service
sudo systemctl start hardware-test.service
sudo systemctl status hardware-test.service
```

> **systemd 环境下的 .env 加载**：应用启动时会按以下优先级搜索 `.env` 文件：
> 1. `<项目根目录>/.env`（如 `/www/wwwroot/hardware-test-system/.env`）
> 2. `<backend 目录>/.env`
> 3. 当前工作目录 `.env`
> 4. `python-dotenv` 自动向上搜索
>
> 确保 `.env` 在项目根目录下即可。

### 5.2 Nginx 反向代理

创建 `/etc/nginx/conf.d/hardware-test.conf`：

```nginx
upstream hardware_test_backend {
    server 127.0.0.1:8100;
    keepalive 16;
}

server {
    listen 80;
    server_name your-domain.com;  # 替换为实际域名

    # 日志
    access_log /var/log/nginx/hardware-test-access.log;
    error_log /var/log/nginx/hardware-test-error.log;

    # 客户端请求体上限（Excel 上传等）
    client_max_body_size 50m;

    # 前端静态文件
    location / {
        root /www/wwwroot/hardware-test-system/frontend;
        index index.html;
        try_files $uri $uri/ /index.html;
    }

    # 后端 API 代理
    location /api/ {
        proxy_pass http://hardware_test_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 120s;
        proxy_send_timeout 120s;
    }

    # 静态资源缓存
    location ~* \.(ico|css|js|gif|jpe?g|png|woff2?)$ {
        root /www/wwwroot/hardware-test-system/frontend;
        expires 7d;
        add_header Cache-Control "public, immutable";
    }
}
```

重载 Nginx：

```bash
sudo nginx -t
sudo systemctl reload nginx
```

### 5.3 防火墙配置

**firewalld（CentOS/RHEL）**：

```bash
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https  # 如果启用 SSL
sudo firewall-cmd --reload
```

**ufw（Ubuntu）**：

```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp  # 如果启用 SSL
sudo ufw reload
```

> **注意**：不要暴露 8000 端口到公网，仅允许本地回环访问。

---

## 6. 健康检查

### 6.1 API 健康检查

```bash
# 基本连通性
curl -s http://127.0.0.1:8100/api/commands?search= | python3 -m json.tool

# 期望返回: {"data": [], "message": "OK", "success": true}
```

### 6.2 数据库连接检查

```bash
# 通过应用 API 间接触达
curl -s http://127.0.0.1:8000/api/commands?search=&category=硬件检测
```

### 6.3 systemd 服务状态

```bash
sudo systemctl status hardware-test.service
sudo journalctl -u hardware-test.service -f  # 实时日志
```

---

## 7. SSL/HTTPS 配置（可选）

使用 Let's Encrypt + Certbot：

```bash
# 安装 certbot
sudo apt install certbot python3-certbot-nginx  # Ubuntu
sudo dnf install certbot python3-certbot-nginx  # CentOS

# 获取证书
sudo certbot --nginx -d your-domain.com

# 自动续期
sudo systemctl enable certbot.timer
```

---

## 8. 常见问题排查

### 8.1 数据库连接失败：密码含特殊字符

**症状**：启动报错 `sqlalchemy.exc.OperationalError: (pymysql.err.OperationalError) (1045, "Access denied")`

**原因**：旧版本代码未对密码进行 URL 编码，密码中的 `@`、`/`、`:` 等字符破坏了连接 URL 格式。

**修复**：当前版本已在 `DATABASE_URL` 构造时使用 `urllib.parse.quote_plus()` 对密码编码。确保使用最新代码。

### 8.2 端口冲突

**症状**：`OSError: [Errno 48] Address already in use`

```bash
# 查找占用端口的进程
sudo lsof -i :8100

# 终止进程
sudo kill -9 <PID>
```

### 8.3 MySQL 连接被拒绝

**症状**：`Can't connect to MySQL server on '127.0.0.1' (61)`

```bash
# 确认 MySQL 运行
sudo systemctl status mysql

# 确认监听端口
sudo netstat -tlnp | grep 3306

# 确认用户权限
mysql -u hts_user -p -h 127.0.0.1 -e "SELECT 1;"
```

### 8.4 systemd 服务无法启动

```bash
# 查看详细日志
sudo journalctl -u hardware-test.service -n 50 --no-pager

# 常见原因：
# 1. .env 文件缺失或路径不正确 → 确认 /opt/hardware-test-system/.env 存在
# 2. venv 中缺少依赖 → 重新运行 pip install -r requirements.txt
# 3. 文件权限 → 确认 www-data 用户可读项目文件
# 4. WorkingDirectory 不存在 → 确认路径正确
```

### 8.5 .env 不生效

确认 `.env` 位于以下任一位置：
- `/www/wwwroot/hardware-test-system/.env`（最优先）
- `/opt/hardware-test-system/backend/.env`
- systemd WorkingDirectory 下的 `.env`

可通过系统环境变量直接设置以绕过文件搜索：

```bash
# 在 systemd service 中添加：
Environment="DB_HOST=127.0.0.1"
Environment="DB_PASSWORD=secret"
```

### 8.6 前端页面空白

1. 确认 Nginx `root` 指向正确的 `frontend` 目录
2. 检查浏览器控制台是否报跨域错误
3. 确认 `index.html` 中 `API_BASE_URL` 变量指向正确的后端地址

---

## 9. 备份建议

```bash
# 数据库备份
mysqldump -u hts_user -p hardware > backup_$(date +%Y%m%d).sql

# 配置文件备份
tar czf config_backup_$(date +%Y%m%d).tar.gz .env

# 设置 crontab 自动备份
# 0 2 * * * /opt/hardware-test-system/scripts/backup.sh
```
