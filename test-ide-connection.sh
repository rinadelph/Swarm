#!/bin/bash

# Test to understand how /ide establishes connection

echo "=== Testing Claude /ide Connection ==="

# Check for any listening ports before running claude
echo "1. Checking for listening ports before Claude..."
netstat -tlnp 2>/dev/null | grep -E "(claude|node)" || echo "No claude/node ports found"

# Start Claude in background and capture output
echo -e "\n2. Starting Claude and typing /ide..."
(
    export NODE_TLS_REJECT_UNAUTHORIZED="0"
    echo -e "/ide\nexit" | claude --debug 2>&1
) > claude-ide-output.log &

CLAUDE_PID=$!

# Wait a bit for Claude to start
sleep 3

# Check for new listening ports
echo -e "\n3. Checking for listening ports after /ide..."
netstat -tlnp 2>/dev/null | grep -E "(claude|node)" || echo "No new ports found"

# Check for any socket files
echo -e "\n4. Checking for socket files..."
find /tmp -name "*claude*" -o -name "*ide*" 2>/dev/null | head -10

# Check process list
echo -e "\n5. Checking processes..."
ps aux | grep -E "(claude|node)" | grep -v grep | head -5

# Wait for Claude to finish
wait $CLAUDE_PID

echo -e "\n6. Claude output:"
cat claude-ide-output.log | grep -A 20 -B 5 "/ide" || cat claude-ide-output.log

# Check if VS Code is running
echo -e "\n7. Checking VS Code processes..."
ps aux | grep -i "code" | grep -v grep | head -5