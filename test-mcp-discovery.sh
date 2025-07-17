#!/bin/bash

echo "=== Testing MCP Discovery Process ==="

# 1. Use strace to see how Claude connects when /ide is typed
echo "1. Starting Claude with strace to capture system calls..."

# Create a temporary file for strace output
STRACE_LOG="mitm-claude/logs/claude_strace.log"
mkdir -p mitm-claude/logs

# Start Claude with strace, filtering for relevant calls
echo "Running: strace -f -e trace=network,connect,bind,socket,open,read,write -o $STRACE_LOG claude --debug"
echo "Type '/ide' when Claude starts, then exit after a few seconds"

# Run strace
strace -f -e trace=network,connect,bind,socket,open,read,write -o "$STRACE_LOG" claude --debug &
STRACE_PID=$!

# Wait for user to test
echo -e "\nWaiting 15 seconds for you to type /ide..."
sleep 15

# Kill strace/claude
kill $STRACE_PID 2>/dev/null

# 2. Analyze the strace output
echo -e "\n2. Analyzing strace output for MCP connections..."
echo "Looking for port 40145 connections:"
grep -E "connect|40145|\.lock" "$STRACE_LOG" | head -20

echo -e "\nLooking for lock file access:"
grep -E "open.*\.claude|\.lock" "$STRACE_LOG" | head -20

echo -e "\nLooking for WebSocket or stdio connections:"
grep -E "socket|pipe|WebSocket" "$STRACE_LOG" | head -20

# 3. Check if VS Code extension uses stdio or WebSocket
echo -e "\n3. Checking VS Code extension MCP transport..."
VSCODE_EXT_LOG=$(find ~/.config/Code/logs -name "*.log" -type f -exec grep -l "MCP\|40145" {} \; 2>/dev/null | head -1)
if [ -n "$VSCODE_EXT_LOG" ]; then
    echo "Found VS Code log: $VSCODE_EXT_LOG"
    grep -E "MCP|transport|40145" "$VSCODE_EXT_LOG" | tail -10
fi

echo -e "\nFull strace log saved to: $STRACE_LOG"