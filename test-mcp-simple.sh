#!/bin/bash

echo "=== Simple MCP Interception Test ==="

# Kill any existing processes
pkill -f mitm-websocket.py

# Clean logs
rm -rf mitm-claude/logs/mcp_websocket/*
mkdir -p mitm-claude/logs/mcp_websocket

# 1. Check current VS Code MCP server
echo "1. Finding VS Code MCP server..."
VSCODE_PID=$(pgrep -f "Code Helper" | head -1)
if [ -n "$VSCODE_PID" ]; then
    echo "VS Code helper PID: $VSCODE_PID"
    lsof -p $VSCODE_PID 2>/dev/null | grep -E "TCP|LISTEN" | grep 40145 || echo "No port 40145 found"
fi

# 2. Start WebSocket proxy
echo -e "\n2. Starting WebSocket MITM proxy..."
python3 mitm-websocket.py &
PROXY_PID=$!
sleep 2

# 3. Check lock files
echo -e "\n3. Lock files in ~/.claude/ide/:"
ls -la ~/.claude/ide/*.lock 2>/dev/null

# 4. Find Claude processes that might use /ide
echo -e "\n4. Active Claude processes:"
ps aux | grep -E "claude.*debug|claude$" | grep -v grep | awk '{print $2, $11, $12}' | head -5

# 5. Monitor for connections
echo -e "\n5. Monitoring for WebSocket connections..."
echo "Open another terminal and run: claude --debug"
echo "Then type: /ide"
echo "Press Ctrl+C to stop monitoring"

# Monitor both proxy logs and captured messages
watch -n 1 'echo "=== Proxy Log ==="; tail -5 mitm-claude/logs/websocket_proxy.log 2>/dev/null; echo -e "\n=== Captured Messages ==="; ls -la mitm-claude/logs/mcp_websocket/ 2>/dev/null | tail -5; echo -e "\n=== Port Status ==="; netstat -tlnp 2>/dev/null | grep -E "40145|40146"'