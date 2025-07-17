#!/bin/bash

# Run the Claude Code MITM proxy test in tmux

SESSION_NAME="claude-mitm-test"

# Kill existing session if it exists
tmux kill-session -t $SESSION_NAME 2>/dev/null

# Create new tmux session
tmux new-session -d -s $SESSION_NAME -n "setup"

# Window 0: Setup and initial run
tmux send-keys -t $SESSION_NAME:0 "cd $(pwd)" C-m
tmux send-keys -t $SESSION_NAME:0 "./setup-mitm.sh" C-m

# Window 1: MITM Proxy logs
tmux new-window -t $SESSION_NAME:1 -n "proxy-logs"
tmux send-keys -t $SESSION_NAME:1 "cd $(pwd)" C-m
tmux send-keys -t $SESSION_NAME:1 "mkdir -p mitm-claude/logs" C-m
tmux send-keys -t $SESSION_NAME:1 "tail -f mitm-claude/logs/mitmproxy.log" C-m

# Window 2: API request monitor
tmux new-window -t $SESSION_NAME:2 -n "api-monitor"
tmux send-keys -t $SESSION_NAME:2 "cd $(pwd)" C-m
tmux send-keys -t $SESSION_NAME:2 "watch -n 1 'ls -la mitm-claude/logs/api_requests/ | tail -20'" C-m

# Window 3: Test Claude Code with proxy
tmux new-window -t $SESSION_NAME:3 -n "claude-test"
tmux send-keys -t $SESSION_NAME:3 "cd $(pwd)" C-m
tmux send-keys -t $SESSION_NAME:3 "echo 'Ready to test Claude Code with proxy'" C-m
tmux send-keys -t $SESSION_NAME:3 "echo 'Run: ./launch-claude-proxy.sh /ide'" C-m
tmux send-keys -t $SESSION_NAME:3 "echo 'Or test other commands like: ./launch-claude-proxy.sh --help'" C-m

# Window 4: Capture analysis
tmux new-window -t $SESSION_NAME:4 -n "analysis"
tmux send-keys -t $SESSION_NAME:4 "cd $(pwd)/mitm-claude" C-m
tmux send-keys -t $SESSION_NAME:4 "echo 'Analysis window - captures will be saved here'" C-m

# Attach to session
echo "Tmux session '$SESSION_NAME' created with windows:"
echo "  0: setup - Initial setup"
echo "  1: proxy-logs - MITM proxy logs"
echo "  2: api-monitor - API request monitor"
echo "  3: claude-test - Test Claude Code commands"
echo "  4: analysis - Capture analysis"
echo ""
echo "Attaching to session..."

tmux attach-session -t $SESSION_NAME