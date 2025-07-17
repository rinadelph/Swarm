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
