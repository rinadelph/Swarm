#!/bin/bash

# Test Claude /ide with MITM proxy in tmux

export PATH="$HOME/.local/bin:$PATH"
SESSION_NAME="claude-ide-test"

# Kill existing session
tmux kill-session -t $SESSION_NAME 2>/dev/null

# Create new session
tmux new-session -d -s $SESSION_NAME -n "proxy"

# Window 0: Start proxy
tmux send-keys -t $SESSION_NAME:proxy "cd $(pwd)" C-m
tmux send-keys -t $SESSION_NAME:proxy "./simple-test.sh" C-m

# Window 1: Claude test
tmux new-window -t $SESSION_NAME -n "claude"
tmux send-keys -t $SESSION_NAME:claude "cd $(pwd)" C-m
tmux send-keys -t $SESSION_NAME:claude "# Set proxy environment" C-m
tmux send-keys -t $SESSION_NAME:claude "export HTTP_PROXY='http://localhost:9234'" C-m
tmux send-keys -t $SESSION_NAME:claude "export HTTPS_PROXY='http://localhost:9234'" C-m
tmux send-keys -t $SESSION_NAME:claude "export NODE_EXTRA_CA_CERTS='$HOME/.mitmproxy/mitmproxy-ca-cert.pem'" C-m
tmux send-keys -t $SESSION_NAME:claude "export NODE_TLS_REJECT_UNAUTHORIZED='0'" C-m
tmux send-keys -t $SESSION_NAME:claude "# Now run: claude --debug" C-m
tmux send-keys -t $SESSION_NAME:claude "# Then type: /ide" C-m

# Window 2: Monitor logs
tmux new-window -t $SESSION_NAME -n "logs"
tmux send-keys -t $SESSION_NAME:logs "cd $(pwd)" C-m
tmux send-keys -t $SESSION_NAME:logs "tail -f mitm-claude/logs/mitmproxy_manual.log" C-m

# Window 3: API monitor
tmux new-window -t $SESSION_NAME -n "api"
tmux send-keys -t $SESSION_NAME:api "cd $(pwd)" C-m
tmux send-keys -t $SESSION_NAME:api "watch -n 1 'ls -la mitm-claude/logs/api_requests/'" C-m

echo "Tmux session created. Windows:"
echo "  0 (proxy): MITM proxy running"
echo "  1 (claude): Ready to run 'claude --debug' then type '/ide'"
echo "  2 (logs): Proxy logs"
echo "  3 (api): API request monitor"
echo
echo "Attaching to session..."
tmux attach-session -t $SESSION_NAME:claude