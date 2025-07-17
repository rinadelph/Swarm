#!/bin/bash

# Simple test without expect - manual interaction

export PATH="$HOME/.local/bin:$PATH"

# Start mitmdump in background (headless version)
echo "Starting mitmdump on port 9234..."
mitmdump \
    --listen-port 9234 \
    --set confdir=~/.mitmproxy \
    --set save_stream_file="mitm-claude/captures/manual_test.mitm" \
    --showhost \
    -s mitm-claude/scripts/analyze_requests.py \
    > mitm-claude/logs/mitmproxy_manual.log 2>&1 &

MITM_PID=$!
echo "MITM proxy started with PID: $MITM_PID"

# Wait for proxy to start
sleep 2

# Set proxy environment
export HTTP_PROXY="http://localhost:9234"
export HTTPS_PROXY="http://localhost:9234"
export http_proxy="http://localhost:9234"
export https_proxy="http://localhost:9234"
export NODE_EXTRA_CA_CERTS="$HOME/.mitmproxy/mitmproxy-ca-cert.pem"
export NODE_TLS_REJECT_UNAUTHORIZED="0"

echo
echo "Proxy is running. Now run claude with debug:"
echo "claude --debug"
echo
echo "Then type: /ide"
echo
echo "Press Ctrl+C to stop the proxy when done."
echo

# Keep proxy running
trap "kill $MITM_PID 2>/dev/null; echo 'Proxy stopped.'" EXIT
wait $MITM_PID