#!/bin/bash

echo "=== Testing Neovim MCP Plugin in tmux (headless) ==="

# Kill any existing session
tmux kill-session -t nvim_mcp 2>/dev/null
pkill -f mcp_server

# Create new session
tmux new-session -d -s nvim_mcp -n main

# Split into 3 panes
tmux split-window -v -t nvim_mcp:main -p 40
tmux split-window -h -t nvim_mcp:main.1

# Start Neovim in pane 0
tmux send-keys -t nvim_mcp:main.0 "cd $(pwd) && nvim -u init.lua test_file.txt" C-m

# Wait for Neovim to load
sleep 2

# Start MCP server
tmux send-keys -t nvim_mcp:main.0 ":MCPStart 45000" C-m
sleep 1

# Check status
tmux send-keys -t nvim_mcp:main.0 ":MCPStatus" C-m
sleep 1

# Start monitor in pane 1
tmux send-keys -t nvim_mcp:main.1 "while true; do clear; echo '=== Lock Files ==='; ls -la ~/.claude/ide/neovim_*.lock 2>/dev/null || echo 'No lock files'; echo; echo '=== Port Status ==='; ss -tlnp | grep 45000 2>/dev/null || echo 'Port not in use'; echo; echo '=== Processes ==='; ps aux | grep mcp_server | grep -v grep; sleep 2; done" C-m

# Prepare test in pane 2
tmux send-keys -t nvim_mcp:main.2 "echo 'Ready to test. Run: python3 test_client.py'" C-m

# Wait a bit
sleep 3

# Capture current state
echo "=== Neovim Pane ==="
tmux capture-pane -t nvim_mcp:main.0 -p | tail -20

echo -e "\n=== Monitor Pane ==="
tmux capture-pane -t nvim_mcp:main.1 -p | tail -15

echo -e "\n=== Session Info ==="
echo "Session name: nvim_mcp"
echo "To attach: tmux attach -t nvim_mcp"
echo "To kill: tmux kill-session -t nvim_mcp"

# Check if MCP server actually started
echo -e "\n=== Quick Port Check ==="
if ss -tlnp 2>/dev/null | grep -q 45000; then
    echo "✅ Port 45000 is listening"
    
    # Try a quick connection test
    echo -e "\n=== Testing connection ==="
    python3 -c "
import websocket
try:
    ws = websocket.WebSocket()
    ws.connect('ws://localhost:45000')
    print('✅ Successfully connected to MCP server!')
    ws.close()
except Exception as e:
    print(f'❌ Connection failed: {e}')
"
else
    echo "❌ Port 45000 is not listening"
fi