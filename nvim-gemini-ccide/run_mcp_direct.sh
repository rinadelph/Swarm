#!/bin/bash

echo "=== Neovim MCP Server (Direct) ==="
echo ""

# Clean up any existing processes
echo "Cleaning up existing processes..."
tmux kill-server 2>/dev/null || true
pkill -f nvim 2>/dev/null || true
pkill -f mcp_server 2>/dev/null || true
rm -f ~/.claude/ide/neovim_*.lock 2>/dev/null || true

sleep 1

# Change to plugin directory
cd /home/alejandro/VPS/CCIde/nvim-gemini-ccide

echo ""
echo "Starting Neovim with MCP server (dynamic port)..."
echo ""

# Start Neovim with MCP auto-start (port 0 means dynamic)
nvim -u init.lua -c ":MCPStart 0" -c ":messages" test_file.txt