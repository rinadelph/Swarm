#!/bin/bash

echo "=== Setting up MCP Test in tmux ==="

# Kill existing session
tmux kill-session -t mcp_test 2>/dev/null

# Create new session with horizontal split
tmux new-session -d -s mcp_test -n test
tmux split-window -h -t mcp_test:test

# Left pane: Server
tmux send-keys -t mcp_test:test.0 "echo '=== MCP Server ===' && cd $(pwd) && python3 mcp_server_v15.py 45003 2>&1 | tee server.log" C-m

# Wait for server to start
sleep 3

# Right pane: Client test
tmux send-keys -t mcp_test:test.1 "echo '=== Client Test ===' && cd $(pwd) && python3 test_client.py 2>&1 | tee client.log" C-m

echo "✅ Test running in tmux session 'mcp_test'"
echo ""
echo "Commands:"
echo "  Watch live:     tmux attach -t mcp_test"
echo "  Server pane:    tmux capture-pane -t mcp_test:test.0 -p"
echo "  Client pane:    tmux capture-pane -t mcp_test:test.1 -p"
echo "  Kill session:   tmux kill-session -t mcp_test"

# Wait for test to complete
sleep 5

echo -e "\n=== Server Output ==="
tmux capture-pane -t mcp_test:test.0 -p | grep -A20 "MCP Server"

echo -e "\n=== Client Output ==="
tmux capture-pane -t mcp_test:test.1 -p | grep -A20 "Client Test"