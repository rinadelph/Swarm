#!/bin/bash

echo "=== Finding MCP Connection Details ==="

# 1. Check for listening ports by VS Code or node processes
echo "1. Checking for listening ports..."
sudo netstat -tlnp 2>/dev/null | grep -E "(code|node)" | grep -v "grep" || netstat -tln 2>/dev/null | grep -E ":(3[0-9]{3}|4[0-9]{3}|5[0-9]{3})"

# 2. Check VS Code extension logs
echo -e "\n2. Checking VS Code extension host logs..."
find ~/.config/Code/logs -name "*.log" -mtime -1 2>/dev/null | xargs grep -l "claude\|mcp\|model.*context" 2>/dev/null | head -5

# 3. Check for Unix domain sockets
echo -e "\n3. Checking for Unix domain sockets..."
sudo lsof -U 2>/dev/null | grep -E "(code|node|claude)" | head -10 || echo "Need sudo for socket info"

# 4. Check VS Code processes with open files
echo -e "\n4. Checking VS Code process connections..."
for pid in $(pgrep -f "code.*extensionHost"); do
    echo "Extension host PID: $pid"
    sudo lsof -p $pid 2>/dev/null | grep -E "(LISTEN|ESTABLISHED|sock)" | head -5 || lsof -p $pid 2>/dev/null | grep -E "(LISTEN|ESTABLISHED)" | head -5
done

# 5. Check for MCP-specific patterns in process arguments
echo -e "\n5. Checking process arguments for MCP..."
ps aux | grep -E "(mcp|modelcontext|claude.*ext)" | grep -v grep | head -5

# 6. Check environment variables
echo -e "\n6. Checking MCP-related environment variables..."
env | grep -E "(MCP|MODEL_CONTEXT|CLAUDE)" | head -10

# 7. Trace VS Code extension communications
echo -e "\n7. Looking for IPC/stdio connections..."
ps aux | grep -E "extensionHost.*claude" | grep -v grep