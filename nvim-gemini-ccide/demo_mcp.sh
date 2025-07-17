#!/bin/bash

echo "=== MCP Demo: Neovim + Claude ==="
echo "This will show Neovim (left) running MCP server and Claude (right) connecting to it"
echo ""

# Kill any existing demo session
tmux kill-session -t mcp_demo 2>/dev/null

# Create new session with vertical split
tmux new-session -d -s mcp_demo -n main

# Split vertically (left: Neovim, right: Claude)
tmux split-window -h -t mcp_demo:main

# Left pane: Start Neovim
tmux send-keys -t mcp_demo:main.0 "cd $(pwd)" C-m
tmux send-keys -t mcp_demo:main.0 "clear" C-m
tmux send-keys -t mcp_demo:main.0 "echo '=== Neovim with MCP Server ==='" C-m
tmux send-keys -t mcp_demo:main.0 "echo 'Starting Neovim...'" C-m
tmux send-keys -t mcp_demo:main.0 "echo ''" C-m
tmux send-keys -t mcp_demo:main.0 "nvim -u init.lua test_file.txt" C-m

# Wait for Neovim to load
sleep 2

# Start MCP server in Neovim with dynamic port (0 = auto-assign)
tmux send-keys -t mcp_demo:main.0 ":MCPStart" C-m
sleep 1
tmux send-keys -t mcp_demo:main.0 ":echo 'MCP Server started! Claude can now connect.'" C-m

# Right pane: Prepare for Claude
tmux send-keys -t mcp_demo:main.1 "clear" C-m
tmux send-keys -t mcp_demo:main.1 "echo '=== Claude Code ==='" C-m
tmux send-keys -t mcp_demo:main.1 "echo 'MCP server is running in Neovim (left pane)'" C-m
tmux send-keys -t mcp_demo:main.1 "echo ''" C-m
tmux send-keys -t mcp_demo:main.1 "echo 'Lock file created:'" C-m
tmux send-keys -t mcp_demo:main.1 "ls -la ~/.claude/ide/neovim_*.lock | tail -1" C-m
tmux send-keys -t mcp_demo:main.1 "echo ''" C-m
tmux send-keys -t mcp_demo:main.1 "echo 'Starting Claude...'" C-m
tmux send-keys -t mcp_demo:main.1 "claude --debug" C-m

# Wait for Claude to start
sleep 2

# Show instructions
echo "✅ Demo is ready!"
echo ""
echo "What you'll see:"
echo "  LEFT:  Neovim with MCP server running on a dynamic port"
echo "  RIGHT: Claude ready to connect"
echo ""
echo "To test the connection:"
echo "  1. Type '/ide' in Claude (right pane)"
echo "  2. Claude should show 'Connected to Neovim'"
echo "  3. Claude can now see and interact with your Neovim session!"
echo ""
echo "Attaching to tmux session..."
sleep 2

# Attach to the session
tmux attach -t mcp_demo