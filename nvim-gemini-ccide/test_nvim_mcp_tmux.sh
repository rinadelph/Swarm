#!/bin/bash

echo "=== Testing Neovim MCP Plugin in tmux ==="

# Kill any existing session
tmux kill-session -t nvim_mcp 2>/dev/null

# Create new session with 3 panes
tmux new-session -d -s nvim_mcp -n main

# Split into 3 panes:
# Top: Neovim
# Bottom-left: Monitor (lock files, ports)
# Bottom-right: Claude test
tmux split-window -v -t nvim_mcp:main -p 40
tmux split-window -h -t nvim_mcp:main.1

# Pane 0 (top): Start Neovim
tmux send-keys -t nvim_mcp:main.0 "cd $(pwd)" C-m
tmux send-keys -t nvim_mcp:main.0 "echo '=== Neovim with MCP Plugin ==='" C-m
tmux send-keys -t nvim_mcp:main.0 "nvim -u init.lua test_file.txt" C-m

# Wait for Neovim to load
sleep 2

# Send commands to start MCP server
tmux send-keys -t nvim_mcp:main.0 ":MCPStart 45000" C-m
sleep 1
tmux send-keys -t nvim_mcp:main.0 ":MCPStatus" C-m

# Pane 1 (bottom-left): Monitor
tmux send-keys -t nvim_mcp:main.1 "cd $(pwd)" C-m
tmux send-keys -t nvim_mcp:main.1 "echo '=== Monitoring MCP ==='" C-m
tmux send-keys -t nvim_mcp:main.1 'watch -n 1 '\''echo "=== Lock Files ==="; ls -la ~/.claude/ide/neovim_*.lock 2>/dev/null || echo "No lock files"; echo; echo "=== Port 45000 ==="; netstat -tlnp 2>/dev/null | grep 45000 || ss -tlnp | grep 45000 || echo "Port not in use"; echo; echo "=== MCP Processes ==="; ps aux | grep -E "mcp_server|45000" | grep -v grep'\''' C-m

# Pane 2 (bottom-right): Ready for Claude test
tmux send-keys -t nvim_mcp:main.2 "cd $(pwd)" C-m
tmux send-keys -t nvim_mcp:main.2 "echo '=== Claude Test ==='" C-m
tmux send-keys -t nvim_mcp:main.2 "echo 'When MCP server is running:'" C-m
tmux send-keys -t nvim_mcp:main.2 "echo '1. Run: claude --debug'" C-m
tmux send-keys -t nvim_mcp:main.2 "echo '2. Type: /ide'" C-m
tmux send-keys -t nvim_mcp:main.2 "echo '3. It should connect to Neovim!'" C-m
tmux send-keys -t nvim_mcp:main.2 "echo ''" C-m
tmux send-keys -t nvim_mcp:main.2 "echo 'Or test with: python3 test_client.py'" C-m

echo "✅ tmux session 'nvim_mcp' created"
echo ""
echo "Layout:"
echo "  Top:          Neovim (MCP server should be starting)"
echo "  Bottom-left:  Monitor (watching lock files & port)"
echo "  Bottom-right: Ready for Claude testing"
echo ""
echo "Commands:"
echo "  Attach:  tmux attach -t nvim_mcp"
echo "  Kill:    tmux kill-session -t nvim_mcp"
echo ""
echo "Attaching to session in 3 seconds..."
sleep 3

# Attach to the session
tmux attach -t nvim_mcp