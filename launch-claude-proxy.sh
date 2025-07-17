#!/bin/bash

# Launch Claude Code through MITM proxy

# Set proxy configuration
export HTTP_PROXY="http://localhost:9234"
export HTTPS_PROXY="http://localhost:9234"
export http_proxy="http://localhost:9234"
export https_proxy="http://localhost:9234"

# Set certificate paths
export NODE_EXTRA_CA_CERTS="$HOME/.mitmproxy/mitmproxy-ca-cert.pem"
export SSL_CERT_FILE="$HOME/.mitmproxy/mitmproxy-ca-cert.pem"
export REQUESTS_CA_BUNDLE="$HOME/.mitmproxy/mitmproxy-ca-cert.pem"

# Disable certificate verification if needed (use carefully)
export NODE_TLS_REJECT_UNAUTHORIZED="0"

# Create capture directory with timestamp
CAPTURE_DIR="mitm-claude/captures/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$CAPTURE_DIR"

# Start mitmproxy in background with web interface
echo "Starting mitmproxy..."
mitmproxy \
    --listen-port 9234 \
    --web-port 8081 \
    --set confdir=~/.mitmproxy \
    --set save_stream_file="$CAPTURE_DIR/claude_traffic.mitm" \
    --set termlog_verbosity=info \
    --showhost \
    -s mitm-claude/scripts/analyze_requests.py \
    &> mitm-claude/logs/mitmproxy.log &

MITM_PID=$!
echo "MITM proxy started with PID: $MITM_PID"
echo "Web interface: http://localhost:8081"

# Wait for proxy to start
sleep 2

# Function to cleanup on exit
cleanup() {
    echo "Stopping mitmproxy..."
    kill $MITM_PID 2>/dev/null
    wait $MITM_PID 2>/dev/null
    echo "Proxy stopped."
}

trap cleanup EXIT

# Launch Claude Code with proxy
echo "Launching Claude Code with proxy..."
echo "Capture directory: $CAPTURE_DIR"

# Run claude with arguments passed to this script
claude "$@"

# Keep proxy running for analysis
echo "Claude Code exited. Press Ctrl+C to stop the proxy and exit."
wait