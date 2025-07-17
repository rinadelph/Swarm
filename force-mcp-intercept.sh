#!/bin/bash

echo "=== Force MCP Interception ==="

# 1. Kill existing proxy
pkill -f mitm-websocket.py

# 2. Check the actual VS Code lock file format
echo "1. Checking lock file format..."
LOCK_FILE=$(ls -t ~/.claude/ide/*.lock 2>/dev/null | grep -E "/[0-9]+\.lock$" | head -1)
if [ -n "$LOCK_FILE" ]; then
    echo "Found lock file: $LOCK_FILE"
    echo "Content:"
    cat "$LOCK_FILE"
    echo
fi

# 3. Create a wrapper script that Claude will call instead of connecting directly
echo "2. Creating MCP wrapper..."
cat > mcp-wrapper.sh << 'EOF'
#!/bin/bash
# MCP Wrapper - intercepts stdio communication

LOG_DIR="mitm-claude/logs/mcp_stdio"
mkdir -p "$LOG_DIR"

echo "[MCP-Wrapper] Started with args: $@" >> "$LOG_DIR/wrapper.log"

# Run the intercept script with the actual VS Code MCP command
python3 intercept-mcp-stdio.py "$@"
EOF
chmod +x mcp-wrapper.sh

# 4. Start WebSocket proxy
echo "3. Starting WebSocket proxy..."
python3 mitm-websocket.py > mitm-claude/logs/websocket_proxy.log 2>&1 &
WS_PID=$!
sleep 2

# 5. Instructions
echo "4. To test MCP interception:"
echo "   a) In another terminal, run: claude --debug"
echo "   b) Type: /ide"
echo "   c) Watch this terminal for captured traffic"
echo ""
echo "5. Monitoring connections..."
echo "Press Ctrl+C to stop"

# Monitor for activity
while true; do
    clear
    echo "=== WebSocket Connections ==="
    netstat -tlnp 2>/dev/null | grep -E "40145|40146" || echo "No connections on MCP ports"
    
    echo -e "\n=== WebSocket Proxy Log (last 5 lines) ==="
    tail -5 mitm-claude/logs/websocket_proxy.log 2>/dev/null || echo "No proxy logs yet"
    
    echo -e "\n=== Captured MCP Messages ==="
    ls -la mitm-claude/logs/mcp_websocket/ 2>/dev/null | tail -5 || echo "No messages captured yet"
    
    echo -e "\n=== Active Claude Processes ==="
    ps aux | grep -E "claude.*debug" | grep -v grep | awk '{print $2, $11, $12}' | head -3
    
    sleep 2
done