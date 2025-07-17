#!/bin/bash

# Check what /ide does to environment and config

echo "=== Checking Claude IDE Integration ==="

# Check current Claude config
echo "1. Current Claude config:"
jq '.ideIntegration // .ide // empty' ~/.claude.json 2>/dev/null || echo "No IDE config in ~/.claude.json"

# Run claude with /ide and capture environment
echo -e "\n2. Running Claude /ide and checking environment..."
(
    claude << EOF
/ide
/status
exit
EOF
) 2>&1 | tee claude-ide-test.log

# Check if config changed
echo -e "\n3. Checking if config changed:"
jq '.ideIntegration // .ide // empty' ~/.claude.json 2>/dev/null || echo "No IDE config found"

# Look for any new processes
echo -e "\n4. Checking for IDE-related processes:"
ps aux | grep -E "(mcp|model.*context|claude.*ide)" | grep -v grep

# Check VS Code extension state
echo -e "\n5. Checking VS Code extension state:"
code --list-extensions | grep -i claude || echo "No Claude extension found via CLI"

# Parse the output
echo -e "\n6. IDE command output:"
grep -A 10 "/ide" claude-ide-test.log | grep -v "^>" || echo "No /ide output captured"