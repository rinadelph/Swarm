#!/bin/bash

echo "=== Testing Neovim MCP Server ==="

# Make scripts executable
chmod +x mcp_server.py

# Create test init file
cat > test_mcp_init.lua << 'EOF'
-- Add plugin to runtimepath
vim.opt.runtimepath:append(vim.fn.getcwd())

-- Set up the plugin
require('nvim-gemini-ccide').setup({
  auto_start = true,  -- Auto-start MCP server
  port = 45000,       -- Use a specific port for testing
  keymaps = true,
})

-- Show commands
print([[
Neovim MCP Server Test

Commands:
- :MCPStart [port]  - Start MCP server
- :MCPStop          - Stop MCP server  
- :MCPStatus        - Check server status
- :MCPTest          - Test tools locally

The server should auto-start on port 45000.
Check ~/.claude/ide/ for the lock file.
]])

-- Also manually start to see output
vim.defer_fn(function()
  vim.cmd('MCPStatus')
end, 2000)
EOF

# Test Python MCP server directly
echo -e "\n1. Testing Python MCP server..."
timeout 5 python3 mcp_server.py 45001 &
PYTHON_PID=$!
sleep 2

# Check if it's running
if ps -p $PYTHON_PID > /dev/null; then
    echo "✅ Python MCP server started"
    
    # Test WebSocket connection
    python3 -c "
import websocket
import json

try:
    ws = websocket.WebSocket()
    ws.connect('ws://localhost:45001')
    
    # Test tools/list
    ws.send(json.dumps({
        'jsonrpc': '2.0',
        'method': 'tools/list',
        'id': 1
    }))
    
    response = ws.recv()
    data = json.loads(response)
    print('✅ Got response:', data)
    ws.close()
except Exception as e:
    print('❌ Connection failed:', e)
"
else
    echo "❌ Python MCP server failed to start"
fi

# Kill the test server
kill $PYTHON_PID 2>/dev/null

# Launch Neovim
echo -e "\n2. Launching Neovim with MCP server..."
nvim -u test_mcp_init.lua

# Cleanup
rm -f test_mcp_init.lua