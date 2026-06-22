#!/bin/bash
# 硬件测试系统 - 自动重启脚本
# 用法: ./restart.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKEND_DIR="$SCRIPT_DIR/backend"
LOG_FILE="/tmp/hwtest.log"
PORT=8000
PYTHON_BIN="/Library/Developer/CommandLineTools/Library/Frameworks/Python3.framework/Versions/3.9/Resources/Python.app/Contents/MacOS/Python"

echo "=== 硬件测试系统 - 服务重启 ==="

# 1. 杀掉占用端口的旧进程
echo "[1/3] 检查并停止旧进程..."
OLD_PIDS=$(lsof -ti:$PORT 2>/dev/null | grep -v Quark || true)
if [ -n "$OLD_PIDS" ]; then
    for pid in $OLD_PIDS; do
        CMD=$(ps -p $pid -o command= 2>/dev/null || echo "")
        if echo "$CMD" | grep -q "app.py"; then
            echo "  停止进程 PID=$pid"
            kill -9 $pid 2>/dev/null || true
        fi
    done
    sleep 1
else
    echo "  没有运行中的服务进程"
fi

# 2. 启动新进程
echo "[2/3] 启动后端服务..."
cd "$BACKEND_DIR"
nohup "$PYTHON_BIN" app.py > "$LOG_FILE" 2>&1 &
NEW_PID=$!
echo "  新进程 PID=$NEW_PID"

# 3. 等待服务就绪并验证
echo "[3/3] 等待服务就绪..."
for i in $(seq 1 15); do
    sleep 1
    if curl -sf -o /dev/null "http://127.0.0.1:$PORT/api/health" 2>/dev/null; then
        echo "  服务已就绪 (${i}s)"
        break
    fi
    if [ $i -eq 15 ]; then
        echo "  警告: 服务启动超时，请检查日志: tail -f $LOG_FILE"
    fi
done

echo ""
echo "=== 重启完成 ==="
echo "  后端: http://127.0.0.1:$PORT"
echo "  日志: $LOG_FILE"
echo "  提示: 请在浏览器中按 Cmd+Shift+R 强制刷新页面"
