#!/bin/bash

echo "=== Setting up MCP Test Environment in tmux ==="

# Kill any existing test session
tmux kill-session -t mcp_test 2>/dev/null

# Create new session with 4 panes
tmux new-session -d -s mcp_test -n main

# Split into 4 panes:
# [0] Server logs
# [1] Client tests  
# [2] Server monitor
# [3] Command input
tmux split-window -h -t mcp_test:main
tmux split-window -v -t mcp_test:main.0
tmux split-window -v -t mcp_test:main.1

# Set pane titles
tmux select-pane -t mcp_test:main.0 -T "MCP Server"
tmux select-pane -t mcp_test:main.1 -T "Test Client"
tmux select-pane -t mcp_test:main.2 -T "Server Monitor"
tmux select-pane -t mcp_test:main.3 -T "Commands"

# Start server in pane 0
tmux send-keys -t mcp_test:main.0 "cd $(pwd)" C-m
tmux send-keys -t mcp_test:main.0 "echo '=== MCP Server Starting ==='" C-m
tmux send-keys -t mcp_test:main.0 "python3 simple_mcp_server.py 45003 2>&1" C-m

# Monitor server in pane 2
tmux send-keys -t mcp_test:main.2 "cd $(pwd)" C-m
tmux send-keys -t mcp_test:main.2 "sleep 2 && watch -n 1 'echo \"=== Port Status ===\"; netstat -tlnp 2>/dev/null | grep 45003 || ss -tlnp | grep 45003; echo; echo \"=== Process ===\"; ps aux | grep \"[s]imple_mcp_server\"'" C-m

# Set up client test in pane 1
tmux send-keys -t mcp_test:main.1 "cd $(pwd)" C-m
tmux send-keys -t mcp_test:main.1 "echo '=== Test Client Ready ==='" C-m
tmux send-keys -t mcp_test:main.1 "echo 'Run: python3 test_client.py'" C-m

# Commands pane
tmux send-keys -t mcp_test:main.3 "cd $(pwd)" C-m
tmux send-keys -t mcp_test:main.3 "echo '=== Commands ==='" C-m
tmux send-keys -t mcp_test:main.3 "echo '1. python3 test_client.py'" C-m
tmux send-keys -t mcp_test:main.3 "echo '2. python3 -m websocket ws://localhost:45003'" C-m
tmux send-keys -t mcp_test:main.3 "echo '3. curl -v http://localhost:45003'" C-m

echo "✅ tmux session 'mcp_test' created with 4 panes"
echo ""
echo "To attach: tmux attach -t mcp_test"
echo "To see pane 0 (server): tmux select-pane -t mcp_test:main.0"
echo "To kill: tmux kill-session -t mcp_test"
echo ""
echo "Pane layout:"
echo "  [0] MCP Server - Running the server"
echo "  [1] Test Client - Ready for client tests"
echo "  [2] Server Monitor - Watching port/process"
echo "  [3] Commands - Quick commands"