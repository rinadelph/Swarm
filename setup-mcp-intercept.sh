#!/bin/bash

echo "=== Setting up MCP Intercept ==="

# 1. Kill existing proxy
pkill -f mitm-websocket.py

# 2. Find the VS Code extension process that's running the MCP server
echo "1. Finding VS Code MCP server process..."
MCP_PID=$(lsof -ti:40145)
if [ -n "$MCP_PID" ]; then
    echo "Found MCP server on port 40145 with PID: $MCP_PID"
    MCP_DETAILS=$(ps -p $MCP_PID -o comm=,args=)
    echo "Process: $MCP_DETAILS"
else
    echo "No process found on port 40145"
fi

# 3. Start our WebSocket proxy
echo -e "\n2. Starting WebSocket MITM proxy..."
python3 mitm-websocket.py > mitm-claude/logs/websocket_proxy.log 2>&1 &
PROXY_PID=$!
sleep 2

# 4. Create a new lock file for our proxy
echo -e "\n3. Creating proxy lock file..."
# Get our proxy PID and create a lock file with that name
cat > ~/.claude/ide/${PROXY_PID}.lock << EOF
{
  "pid": $PROXY_PID,
  "workspaceFolders": [],
  "ideName": "MCP Proxy",
  "transport": "ws",
  "port": 40146,
  "runningInWindows": false,
  "authToken": "proxy-intercept-$(date +%s)"
}
EOF
echo "Created lock file: ~/.claude/ide/${PROXY_PID}.lock"

# 5. Also create a simple port redirect
echo -e "\n4. Setting up port redirect..."
# Use socat or iptables to redirect if needed
which socat > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "Starting socat redirect..."
    socat TCP-LISTEN:40147,fork TCP:localhost:40146 &
    SOCAT_PID=$!
    echo "Socat redirect started on port 40147"
fi

# 6. Show current state
echo -e "\n5. Current MCP setup:"
echo "Lock files:"
ls -la ~/.claude/ide/*.lock | tail -5
echo -e "\nListening ports:"
netstat -tlnp 2>/dev/null | grep -E "4014[5-7]" || ss -tlnp | grep -E "4014[5-7]"

echo -e "\n6. To test:"
echo "   1. Run: claude --debug"
echo "   2. Type: /ide"
echo "   3. Check mitm-claude/logs/mcp_websocket/ for captured messages"

# 7. Monitor in background
echo -e "\n7. Starting monitor..."
./force-mcp-intercept.sh