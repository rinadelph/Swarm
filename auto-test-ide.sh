#!/bin/bash

# Automated test script for Claude Code /ide command with MITM proxy

# Add local bin to PATH for mitmproxy
export PATH="$HOME/.local/bin:$PATH"

SESSION_NAME="claude-ide-test"
CAPTURE_DIR="mitm-claude/captures/$(date +%Y%m%d_%H%M%S)"

# Kill existing session
tmux kill-session -t $SESSION_NAME 2>/dev/null

# Create directories
mkdir -p "$CAPTURE_DIR"
mkdir -p mitm-claude/logs/api_requests

# Create tmux session with initial window
tmux new-session -d -s $SESSION_NAME -n "proxy"

# Window 0: Start MITM proxy
tmux send-keys -t $SESSION_NAME:0 "cd $(pwd)" C-m
tmux send-keys -t $SESSION_NAME:0 "echo 'Starting MITM proxy on port 9234...'" C-m
tmux send-keys -t $SESSION_NAME:0 "mitmproxy \
    --listen-port 9234 \
    --web-port 8081 \
    --set confdir=~/.mitmproxy \
    --set save_stream_file='$CAPTURE_DIR/claude_ide_traffic.mitm' \
    --set termlog_verbosity=debug \
    --showhost \
    -s mitm-claude/scripts/analyze_requests.py \
    2>&1 | tee mitm-claude/logs/mitmproxy_$(date +%Y%m%d_%H%M%S).log" C-m

# Wait for proxy to start
sleep 3

# Window 1: Run Claude with debug mode through proxy
tmux new-window -t $SESSION_NAME:1 -n "claude-debug"
tmux send-keys -t $SESSION_NAME:1 "cd $(pwd)" C-m

# Set proxy environment variables
tmux send-keys -t $SESSION_NAME:1 "export HTTP_PROXY='http://localhost:9234'" C-m
tmux send-keys -t $SESSION_NAME:1 "export HTTPS_PROXY='http://localhost:9234'" C-m
tmux send-keys -t $SESSION_NAME:1 "export http_proxy='http://localhost:9234'" C-m
tmux send-keys -t $SESSION_NAME:1 "export https_proxy='http://localhost:9234'" C-m
tmux send-keys -t $SESSION_NAME:1 "export NODE_EXTRA_CA_CERTS='$HOME/.mitmproxy/mitmproxy-ca-cert.pem'" C-m
tmux send-keys -t $SESSION_NAME:1 "export NODE_TLS_REJECT_UNAUTHORIZED='0'" C-m

# Create expect script to automate /ide command
cat > /tmp/claude_ide_test.exp << 'EOF'
#!/usr/bin/expect -f

set timeout 30

# Start claude in debug mode
spawn claude --debug

# Wait for prompt
expect {
    ">" { send "/ide\r" }
    timeout { 
        puts "Timeout waiting for claude prompt"
        exit 1
    }
}

# Wait a bit to capture the response
sleep 5

# Exit claude
send "\x04"

expect eof
EOF

chmod +x /tmp/claude_ide_test.exp

# Run the expect script
tmux send-keys -t $SESSION_NAME:1 "expect /tmp/claude_ide_test.exp 2>&1 | tee mitm-claude/logs/claude_debug_$(date +%Y%m%d_%H%M%S).log" C-m

# Window 2: Monitor API requests
tmux new-window -t $SESSION_NAME:2 -n "api-monitor"
tmux send-keys -t $SESSION_NAME:2 "cd $(pwd)" C-m
tmux send-keys -t $SESSION_NAME:2 "watch -n 1 'echo \"=== Latest API Requests ===\"; ls -lt mitm-claude/logs/api_requests/ 2>/dev/null | head -10; echo; echo \"=== Request Count ===\"; ls mitm-claude/logs/api_requests/ 2>/dev/null | wc -l'" C-m

# Window 3: View logs
tmux new-window -t $SESSION_NAME:3 -n "logs"
tmux send-keys -t $SESSION_NAME:3 "cd $(pwd)" C-m
tmux send-keys -t $SESSION_NAME:3 "echo 'Logs will be available at:'" C-m
tmux send-keys -t $SESSION_NAME:3 "echo '  - API requests: mitm-claude/logs/api_requests/'" C-m
tmux send-keys -t $SESSION_NAME:3 "echo '  - Proxy logs: mitm-claude/logs/mitmproxy_*.log'" C-m
tmux send-keys -t $SESSION_NAME:3 "echo '  - Claude debug: mitm-claude/logs/claude_debug_*.log'" C-m
tmux send-keys -t $SESSION_NAME:3 "echo '  - Traffic capture: $CAPTURE_DIR/'" C-m

# Attach to session
echo "Test session started. The test will:"
echo "1. Start MITM proxy on port 9234"
echo "2. Run 'claude --debug'"
echo "3. Automatically type '/ide' command"
echo "4. Capture all traffic"
echo "5. Exit after a few seconds"
echo ""
echo "Attaching to tmux session..."

tmux attach-session -t $SESSION_NAME