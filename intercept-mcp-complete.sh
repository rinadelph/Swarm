#!/bin/bash

echo "=== Complete MCP Interception Test ==="

# Kill any existing proxies
pkill -f mitm-websocket.py
pkill -f mitmdump

# Clean up logs
rm -rf mitm-claude/logs/mcp_websocket/*
mkdir -p mitm-claude/logs/mcp_websocket

# 1. Start WebSocket MITM proxy
echo "1. Starting WebSocket MITM proxy..."
python3 mitm-websocket.py > mitm-claude/logs/websocket_proxy.log 2>&1 &
WS_PID=$!
sleep 2

# 2. Find all lock files and examine them
echo -e "\n2. Current lock files:"
find ~/.claude/ide -name "*.lock" -type f | while read lockfile; do
    echo "Lock file: $lockfile"
    cat "$lockfile" | jq '.' 2>/dev/null || cat "$lockfile"
    echo "---"
done

# 3. Create our own lock file that Claude will use
echo -e "\n3. Creating intercept lock file..."
# Get the latest lock file (by PID)
LATEST_LOCK=$(ls -t ~/.claude/ide/*.lock 2>/dev/null | grep -E "/[0-9]+\.lock$" | head -1)
if [ -n "$LATEST_LOCK" ]; then
    echo "Found latest lock file: $LATEST_LOCK"
    # Check if it's JSON format
    if cat "$LATEST_LOCK" | jq '.' >/dev/null 2>&1; then
        # It's JSON, modify the port
        echo "Modifying JSON lock file..."
        jq '. + {port: 40146}' "$LATEST_LOCK" > ~/.claude/ide/40146.lock
    else
        # It's just a port number
        echo "40146" > ~/.claude/ide/40146.lock
    fi
fi

# 4. Run Claude in debug mode
echo -e "\n4. Starting Claude with debug mode..."
cat > test-mcp-ide.exp << 'EOF'
#!/usr/bin/expect -f

set timeout 30

# Start Claude in debug mode
spawn claude --debug

# Wait for prompt
expect ">"

# Send /ide command
send "/ide\r"

# Wait for response
expect {
    "Connected to" {
        puts "\n[SUCCESS] /ide command connected!"
        exp_continue
    }
    "Failed" {
        puts "\n[ERROR] /ide command failed!"
        exp_continue
    }
    timeout {
        puts "\n[TIMEOUT] No response from /ide"
    }
}

# Let it run for a bit to capture traffic
sleep 5

# Exit
send "\003"
expect eof
EOF

chmod +x test-mcp-ide.exp

echo -e "\n5. Running Claude and sending /ide command..."
./test-mcp-ide.exp

# 6. Check captured traffic
echo -e "\n6. Captured MCP messages:"
ls -la mitm-claude/logs/mcp_websocket/ 2>/dev/null | tail -10

# 7. Show WebSocket proxy logs
echo -e "\n7. WebSocket proxy logs:"
tail -20 mitm-claude/logs/websocket_proxy.log

# Cleanup
kill $WS_PID 2>/dev/null
rm -f test-mcp-ide.exp