#!/bin/bash
# Wrapper script to ensure proper logging
LOG_FILE="/tmp/nvim_mcp_debug.log"

# Run Python with unbuffered output, redirecting stderr to log file
exec python3 -u "$@" 2>&1 | while IFS= read -r line; do
    # Check if line is stderr (starts with [SERVER] or contains error patterns)
    if [[ "$line" =~ ^\[SERVER\]|Error|Traceback|Exception ]]; then
        echo "$line" >> "$LOG_FILE"
    fi
    # Always output to stdout for Neovim communication
    echo "$line"
done