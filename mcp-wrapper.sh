#!/bin/bash
# MCP Wrapper - intercepts stdio communication

LOG_DIR="mitm-claude/logs/mcp_stdio"
mkdir -p "$LOG_DIR"

echo "[MCP-Wrapper] Started with args: $@" >> "$LOG_DIR/wrapper.log"

# Run the intercept script with the actual VS Code MCP command
python3 intercept-mcp-stdio.py "$@"
