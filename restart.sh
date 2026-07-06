#!/bin/bash
# 硬件测试系统 - 自动重启脚本
# 用法: ./restart.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKEND_DIR="$SCRIPT_DIR/backend"
LOG_FILE="/tmp/hwtest.log"
PORT="${PORT:-8100}"

# 自动检测 Python 路径
PYTHON_BIN=""
for py in python3.11 python3.10 python3.9 python3; do
    if command -v "$py" &>/dev/null; then
        PYTHON_BIN="$py"
        break
    fi
done
if [ -z "$PYTHON_BIN" ]; then
    echo "错误: 未找到 Python3"
    exit 1
fi

echo "=== 硬件测试系统 - 服务重启 ==="
echo "  Python: $($PYTHON_BIN --version 2>&1)"
echo "  端口:   $PORT"

# 1. 杀掉占用端口的旧进程
echo ""
echo "[1/3] 检查并停止旧进程..."
OLD_PIDS=$(lsof -ti:$PORT 2>/dev/null || true)
if [ -n "$OLD_PIDS" ]; then
    for pid in $OLD_PIDS; do
        CMD=$(ps -p $pid -o command= 2>/dev/null || echo "")
        if echo "$CMD" | grep -q "app.py"; then
            echo "  停止进程 PID=$pid"
            kill "$pid" 2>/dev/null || true
        fi
    done
    # 等待进程优雅退出，最多 3 秒
    for i in 1 2 3; do
        if ! lsof -ti:$PORT &>/dev/null; then
            break
        fi
        sleep 1
    done
    # 强制清理残留
    REMAINING=$(lsof -ti:$PORT 2>/dev/null || true)
    if [ -n "$REMAINING" ]; then
        for pid in $REMAINING; do
            CMD=$(ps -p $pid -o command= 2>/dev/null || echo "")
            if echo "$CMD" | grep -q "app.py"; then
                echo "  强制终止 PID=$pid"
                kill -9 "$pid" 2>/dev/null || true
            fi
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

# 3. 等待服务就绪并验证
echo ""
echo "[3/3] 等待服务就绪..."
READY=false
for i in $(seq 1 15); do
    sleep 1
    if curl -sf -o /dev/null "http://127.0.0.1:$PORT/api/health" 2>/dev/null; then
        echo "  服务已就绪 (${i}s)"
        READY=true
        break
    fi
done

if [ "$READY" = false ]; then
    echo "  警告: 服务启动超时，最后 5 行日志:"
    tail -5 "$LOG_FILE" 2>/dev/null || true
fi

echo ""
echo "=== 重启完成 ==="
echo "  后端: http://127.0.0.1:$PORT"
echo "  日志: tail -f $LOG_FILE"
