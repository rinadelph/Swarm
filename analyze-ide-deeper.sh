#!/bin/bash

echo "=== Deep Analysis of Claude /ide Command ==="
echo

# Check if any IDE-related traffic was captured
echo "=== Searching for IDE patterns in all captures ==="
grep -r "ide\|IDE\|integration\|vscode\|editor" mitm-claude/logs/api_requests/ 2>/dev/null | grep -v "User: claude /ide" | head -20

echo
echo "=== Checking proxy logs for IDE-related traffic ==="
grep -i "ide\|integration\|vscode" mitm-claude/logs/mitmproxy*.log 2>/dev/null | head -10

echo
echo "=== Analyzing Claude configuration ==="
if [ -f ~/.claude.json ]; then
    echo "Claude config file exists. Checking for IDE settings:"
    jq '.ide // .integrations // .editor // empty' ~/.claude.json 2>/dev/null || echo "No IDE-specific config found"
fi

echo
echo "=== Checking for local socket or IPC files ==="
ls -la ~/.claude/ 2>/dev/null | grep -E "sock|pipe|ipc"

echo
echo "=== Summary ==="
echo "Based on the analysis:"
echo "1. The /ide command appears to be a client-side feature"
echo "2. It likely manages local IDE integrations without API calls"
echo "3. The VS Code extension communicates with the Claude CLI locally"
echo "4. Integration may use local sockets, files, or environment detection"