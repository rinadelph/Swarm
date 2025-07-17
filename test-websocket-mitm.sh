#!/bin/bash

# Test WebSocket MITM proxy for MCP communication

echo "=== Testing WebSocket MITM Proxy for MCP ==="

# 1. Kill any existing proxy
echo "1. Stopping any existing proxy..."
pkill -f mitm-websocket.py

# 2. Check current lock file
echo -e "\n2. Current VS Code MCP port lock:"
if [ -f ~/.claude/ide/40145.lock ]; then
    echo "Found lock file: $(cat ~/.claude/ide/40145.lock)"
else
    echo "No lock file found at ~/.claude/ide/40145.lock"
fi

# 3. Start the WebSocket MITM proxy
echo -e "\n3. Starting WebSocket MITM proxy..."
python3 mitm-websocket.py > mitm-claude/logs/websocket_proxy.log 2>&1 &
PROXY_PID=$!
echo "Proxy started with PID: $PROXY_PID"

# Give it time to start
sleep 2

# 4. Check if proxy is running
if ps -p $PROXY_PID > /dev/null; then
    echo "Proxy is running successfully"
else
    echo "ERROR: Proxy failed to start. Check logs:"
    tail -20 mitm-claude/logs/websocket_proxy.log
    exit 1
fi

# 5. Modify the lock file to point to our proxy
echo -e "\n5. Redirecting Claude to use our proxy..."
mkdir -p ~/.claude/ide
echo "40146" > ~/.claude/ide/40145.lock
echo "Lock file updated to use port 40146"

# 6. Run Claude with /ide command
echo -e "\n6. Starting Claude and testing /ide command..."
echo "Run 'claude' in another terminal and type '/ide'"
echo "Press Ctrl+C to stop monitoring"

# 7. Monitor logs
echo -e "\n7. Monitoring MCP messages..."
watch -n 1 'echo "=== WebSocket Proxy Log ==="; tail -10 mitm-claude/logs/websocket_proxy.log; echo -e "\n=== Captured Messages ==="; ls -la mitm-claude/logs/mcp_websocket/ 2>/dev/null | tail -10'