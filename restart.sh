#!/bin/bash
# 硬件测试系统 - 自动重启脚本
# 用法: ./restart.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKEND_DIR="$SCRIPT_DIR/backend"
LOG_FILE="/tmp/hwtest.log"
PORT="${PORT:-8100}"

# 自动检测 Python
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
    echo "错误: 未找到 Python 3.9+"
    exit 1
fi

# 跨平台: 查找占用指定端口的 app.py 进程 PID
find_app_pids() {
    local port=$1
    local pids=""
    if command -v lsof &>/dev/null; then
        # macOS / Linux with lsof
        pids=$(lsof -ti:"$port" 2>/dev/null || true)
    elif command -v fuser &>/dev/null; then
        # Linux
        pids=$(fuser "${port}/tcp" 2>/dev/null | tr -s ' ' || true)
    fi
    # 过滤出 app.py 相关进程
    local result=""
    for pid in $pids; do
        local cmd
        cmd=$(ps -p "$pid" -o command= 2>/dev/null || echo "")
        if echo "$cmd" | grep -q "python.*app\.py"; then
            result="$result $pid"
        fi
    done
    echo "$result"
}

echo "=== 硬件测试系统 - 服务重启 ==="
echo "  Python: $($PYTHON_BIN --version 2>&1)"
echo "  端口:   $PORT"

# 1. 停止旧进程
echo ""
echo "[1/3] 检查并停止旧进程..."
OLD_PIDS=$(find_app_pids "$PORT")
if [ -n "$OLD_PIDS" ]; then
    for pid in $OLD_PIDS; do
        echo "  停止进程 PID=$pid"
        kill "$pid" 2>/dev/null || true
    done
    # 等待优雅退出
    for i in 1 2 3; do
        REMAINING=$(find_app_pids "$PORT")
        [ -z "$REMAINING" ] && break
        sleep 1
    done
    # 强制清理残留
    REMAINING=$(find_app_pids "$PORT")
    if [ -n "$REMAINING" ]; then
        for pid in $REMAINING; do
            echo "  强制终止 PID=$pid"
            kill -9 "$pid" 2>/dev/null || true
        done
        sleep 1
    fi
else
    echo "  没有运行中的服务进程"
fi

# 2. 启动新进程
echo ""
echo "[2/3] 启动后端服务..."
cd "$BACKEND_DIR"
nohup "$PYTHON_BIN" app.py > "$LOG_FILE" 2>&1 &
NEW_PID=$!
echo "  新进程 PID=$NEW_PID"

# 3. 等待就绪
echo ""
echo "[3/3] 等待服务就绪..."
READY=false
for i in $(seq 1 20); do
    sleep 1
    # 同时检查: PID 存活 + health API
    if ! kill -0 "$NEW_PID" 2>/dev/null; then
        echo "  进程已退出，启动失败"
        echo "  最后 10 行日志:"
        tail -10 "$LOG_FILE" 2>/dev/null || true
        exit 1
    fi
    if curl -sf -o /dev/null "http://127.0.0.1:$PORT/api/health" 2>/dev/null; then
        echo "  服务已就绪 (${i}s)"
        READY=true
        break
    fi
done

if [ "$READY" = false ]; then
    echo "  警告: 服务启动超时（20s）"
    echo "  进程状态: $(kill -0 "$NEW_PID" 2>/dev/null && echo '运行中' || echo '已退出')"
    echo "  端口 $PORT 状态: $(ss -tlnp 2>/dev/null | grep ":$PORT " || lsof -i:"$PORT" 2>/dev/null || echo '无监听')"
    echo "  最后 10 行日志:"
    tail -10 "$LOG_FILE" 2>/dev/null || true
fi

# 4. 日志清理: 超过 10MB 时轮转
if [ -f "$LOG_FILE" ]; then
    LOG_SIZE=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
    if [ "$LOG_SIZE" -gt 10485760 ] 2>/dev/null; then
        mv "$LOG_FILE" "${LOG_FILE}.1"
        echo "  日志已轮转 (>10MB)"
    fi
fi

echo ""
echo "=== 重启完成 ==="
echo "  后端: http://127.0.0.1:$PORT"
echo "  日志: tail -f $LOG_FILE"
