#!/bin/bash

echo "=== Simple Neovim MCP Test in tmux ==="

# Create session with single window
tmux new-session -d -s nvim_test

# Start Neovim
tmux send-keys -t nvim_test "cd $(pwd)" C-m
tmux send-keys -t nvim_test "nvim -u init.lua" C-m

# Wait for Neovim to load
sleep 2

# Try to start MCP server
tmux send-keys -t nvim_test ":MCPStart 45000" C-m
sleep 2

# Check status
tmux send-keys -t nvim_test ":MCPStatus" C-m
sleep 1

# Show messages
tmux send-keys -t nvim_test ":messages" C-m
sleep 1

# Capture output
echo "=== Neovim Output ==="
tmux capture-pane -t nvim_test -p | tail -30

# Check if server is running
echo -e "\n=== Server Check ==="
if ps aux | grep -v grep | grep -q "mcp_server.*45000"; then
    echo "✅ MCP server process found"
else
    echo "❌ No MCP server process found"
fi

# Check port
echo -e "\n=== Port Check ==="
if ss -tlnp 2>/dev/null | grep -q 45000; then
    echo "✅ Port 45000 is listening"
else
    echo "❌ Port 45000 not listening"
fi

# Check lock file
echo -e "\n=== Lock File ==="
if ls ~/.claude/ide/neovim_*.lock 2>/dev/null; then
    echo "Content:"
    cat ~/.claude/ide/neovim_*.lock | python3 -m json.tool
else
    echo "No lock file found"
fi

echo -e "\n=== Instructions ==="
echo "To interact: tmux attach -t nvim_test"
echo "To kill: tmux kill-session -t nvim_test"