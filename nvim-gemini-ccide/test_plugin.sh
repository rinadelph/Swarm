#!/bin/bash

echo "=== Claude Code Neovim Plugin Test ==="

# Check prerequisites
echo "1. Checking prerequisites..."

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 not found"
    exit 1
else
    echo "✅ Python 3 found: $(python3 --version)"
fi

# Check websocket-client
if ! python3 -c "import websocket" 2>/dev/null; then
    echo "❌ websocket-client not installed"
    echo "   Run: pip install websocket-client"
    exit 1
else
    echo "✅ websocket-client installed"
fi

# Check VS Code lock files
echo -e "\n2. Checking VS Code connection..."
if ls ~/.claude/ide/*.lock 2>/dev/null; then
    echo "✅ Found lock files:"
    ls -la ~/.claude/ide/*.lock
else
    echo "❌ No lock files found. Make sure VS Code with Claude Code extension is running"
    exit 1
fi

# Make WebSocket bridge executable
chmod +x websocket_bridge.py

# Create minimal test init.vim
echo -e "\n3. Creating test configuration..."
cat > test_init.lua << 'EOF'
-- Add plugin to runtimepath
vim.opt.runtimepath:append(vim.fn.getcwd())

-- Set up the plugin
require('nvim-gemini-ccide').setup({
  auto_connect = false,  -- We'll connect manually for testing
  debug = true,
})

-- Test function
function TestClaudeCode()
  print("=== Testing Claude Code Plugin ===")
  
  -- Test 1: Connection
  vim.cmd('ClaudeConnect')
  vim.wait(3000)  -- Wait for connection
  
  -- Test 2: Status
  vim.cmd('ClaudeStatus')
  
  -- Test 3: List tools
  vim.defer_fn(function()
    vim.cmd('ClaudeListTools')
  end, 1000)
  
  -- Test 4: Open file
  vim.defer_fn(function()
    vim.cmd('ClaudeOpenFile ' .. vim.fn.expand('%:p'))
  end, 2000)
end

-- Show instructions
print([[
Claude Code Plugin Loaded!

Commands to test:
- :ClaudeConnect      - Connect to VS Code
- :ClaudeStatus       - Check connection
- :ClaudeListTools    - List available tools
- :ClaudeOpenFile     - Open current file in VS Code
- :ClaudeOpenDiff     - Show diff in VS Code

Or run: :lua TestClaudeCode()
]])
EOF

# Test the WebSocket bridge directly
echo -e "\n4. Testing WebSocket bridge..."
LOCK_FILE=$(ls ~/.claude/ide/*.lock 2>/dev/null | head -1)
if [ -n "$LOCK_FILE" ]; then
    LOCK_DATA=$(cat "$LOCK_FILE")
    PORT=$(echo "$LOCK_DATA" | grep -o '"port":[0-9]*' | cut -d: -f2)
    AUTH=$(echo "$LOCK_DATA" | grep -o '"authToken":"[^"]*"' | cut -d'"' -f4)
    
    if [ -z "$PORT" ]; then
        # Try extracting from filename
        PORT=$(basename "$LOCK_FILE" .lock)
    fi
    
    echo "Testing connection to port $PORT..."
    
    # Quick connection test
    timeout 5 python3 -c "
import websocket
import json
import sys

try:
    ws = websocket.WebSocket()
    ws.connect('ws://127.0.0.1:$PORT', header={'x-claude-code-ide-authorization': '$AUTH'})
    ws.send(json.dumps({'jsonrpc': '2.0', 'method': 'tools/list', 'id': 1}))
    response = ws.recv()
    data = json.loads(response)
    if 'result' in data:
        print('✅ WebSocket connection successful!')
        print(f'   Found {len(data[\"result\"][\"tools\"])} tools')
    else:
        print('❌ Unexpected response:', data)
    ws.close()
except Exception as e:
    print(f'❌ Connection failed: {e}')
    sys.exit(1)
"
fi

# Launch Neovim with test config
echo -e "\n5. Launching Neovim with test configuration..."
echo "   Run ':lua TestClaudeCode()' to run automated tests"
echo ""

nvim -u test_init.lua test_file.txt

# Cleanup
rm -f test_init.lua test_file.txt