#!/bin/bash

# Script to analyze captured results after test

echo "=== Claude /ide Command Analysis ==="
echo

# Find latest capture directory
LATEST_CAPTURE=$(ls -td mitm-claude/captures/*/ 2>/dev/null | head -1)

if [ -z "$LATEST_CAPTURE" ]; then
    echo "No captures found!"
    exit 1
fi

echo "Latest capture: $LATEST_CAPTURE"
echo

# Check for API requests
echo "=== API Requests Captured ==="
if [ -d "mitm-claude/logs/api_requests" ]; then
    REQUEST_COUNT=$(ls mitm-claude/logs/api_requests/*.json 2>/dev/null | wc -l)
    echo "Total requests captured: $REQUEST_COUNT"
    echo
    
    # Show IDE-related requests
    echo "=== IDE Endpoint Requests ==="
    grep -l "/ide" mitm-claude/logs/api_requests/*.json 2>/dev/null | while read file; do
        echo "File: $file"
        jq -r '.url, .method, .body' "$file" 2>/dev/null | head -20
        echo "---"
    done
fi

# Show latest logs
echo
echo "=== Latest Claude Debug Log ==="
LATEST_DEBUG_LOG=$(ls -t mitm-claude/logs/claude_debug_*.log 2>/dev/null | head -1)
if [ -f "$LATEST_DEBUG_LOG" ]; then
    echo "Log file: $LATEST_DEBUG_LOG"
    echo "Last 50 lines:"
    tail -50 "$LATEST_DEBUG_LOG"
fi

echo
echo "=== Latest Proxy Log ==="
LATEST_PROXY_LOG=$(ls -t mitm-claude/logs/mitmproxy_*.log 2>/dev/null | head -1)
if [ -f "$LATEST_PROXY_LOG" ]; then
    echo "Log file: $LATEST_PROXY_LOG"
    grep -E "(anthropic|claude|/ide)" "$LATEST_PROXY_LOG" | tail -20
fi

# Analyze captured traffic file
echo
echo "=== Traffic Analysis ==="
if [ -f "$LATEST_CAPTURE/claude_ide_traffic.mitm" ]; then
    echo "Traffic file exists: $LATEST_CAPTURE/claude_ide_traffic.mitm"
    echo "You can load this in mitmproxy for detailed analysis:"
    echo "  mitmproxy -r $LATEST_CAPTURE/claude_ide_traffic.mitm"
fi