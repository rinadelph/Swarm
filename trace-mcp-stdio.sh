#!/bin/bash

echo "=== Tracing MCP stdio Communication ==="

# 1. Find Claude Code process
echo "1. Finding Claude Code processes..."
CLAUDE_PIDS=$(pgrep -f "claude" | head -5)
echo "Claude PIDs: $CLAUDE_PIDS"

# 2. Check file descriptors for stdio pipes
echo -e "\n2. Checking Claude process file descriptors..."
for pid in $CLAUDE_PIDS; do
    echo "PID $pid:"
    sudo ls -la /proc/$pid/fd 2>/dev/null | grep -E "(pipe|socket)" | head -5 || ls -la /proc/$pid/fd 2>/dev/null | grep -E "(pipe|socket)" | head -5
done

# 3. Use strace to trace system calls
echo -e "\n3. Starting strace on Claude to capture /ide communication..."
echo "Run this in another terminal: sudo strace -f -e trace=read,write,connect,socket -p <CLAUDE_PID>"

# 4. Check for VS Code extension processes
echo -e "\n4. Finding VS Code extension host processes..."
ps aux | grep -E "extensionHost|Code Helper" | grep -v grep | awk '{print $2}' | while read pid; do
    echo "Extension host PID: $pid"
    sudo lsof -p $pid 2>/dev/null | grep -E "(pipe|socket|node)" | head -3
done

# 5. Monitor for new connections when /ide is typed
echo -e "\n5. Setting up connection monitor..."
echo "Monitoring for new connections. Type /ide in Claude now..."

# Create a script to capture traffic
cat > capture-mcp.sh << 'EOF'
#!/bin/bash
# Capture MCP communication

# Monitor for new connections
watch -n 1 'netstat -anp 2>/dev/null | grep -E "(claude|node)" | grep ESTABLISHED'
EOF

chmod +x capture-mcp.sh

echo -e "\n6. MCP typically uses JSON-RPC over stdio. To intercept:"
echo "   a) Use 'socat' to create a proxy between processes"
echo "   b) Use 'tee' to capture stdio communication"
echo "   c) Modify VS Code extension to log all MCP messages"

# 7. Check if VS Code is passing any special environment to extensions
echo -e "\n7. VS Code extension environment..."
strings /proc/$(pgrep -f "Code" | head -1)/environ 2>/dev/null | grep -E "(CLAUDE|MCP|MODEL)" | head -10